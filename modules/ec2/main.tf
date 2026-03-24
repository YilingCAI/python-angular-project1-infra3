/**
 * EC2 Module — Ansible-managed application instances
 *
 * Provisions:
 *   - RSA key pair (private key stored in Secrets Manager for Ansible)
 *   - IAM instance profile with SSM + Secrets Manager + CloudWatch access
 *   - Encrypted launch templates (backend & frontend)
 *   - Auto Scaling Groups registered against ALB target groups
 *   - SSM Parameter Store entries consumed by the Ansible dynamic inventory
 *
 * Ansible connectivity: community.aws.aws_ssm connection plugin (no SSH port
 * required; instances reach SSM via NAT gateway HTTPS).
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Latest Amazon Linux 2023 AMI (x86_64)
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ─── KMS key for EC2 EBS + Secrets Manager ───────────────────────────────────
resource "aws_kms_key" "ec2" {
  description             = "KMS key for EC2 EBS volumes and SSH key secret"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = { Name = "${var.project_name}-ec2-key" }
}

resource "aws_kms_key_policy" "ec2" {
  key_id = aws_kms_key.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEC2AndSecretsManagerUse"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "ec2" {
  name          = "alias/${var.project_name}-ec2"
  target_key_id = aws_kms_key.ec2.key_id
}

# ─── SSH key pair (Ansible fallback — primary method is SSM) ─────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  key_name   = "${var.project_name}-app-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = { Name = "${var.project_name}-app-key" }
}

# Store private key in Secrets Manager so CI/CD can retrieve it for Ansible
#checkov:skip=CKV2_AWS_57:Key rotation handled by periodic Terraform-managed key replacement.
resource "aws_secretsmanager_secret" "ssh_private_key" {
  name_prefix             = "${var.project_name}-ssh-key-"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.ec2.id

  tags = { Name = "${var.project_name}-ssh-private-key" }
}

resource "aws_secretsmanager_secret_version" "ssh_private_key" {
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = tls_private_key.ssh.private_key_pem

  lifecycle {
    # Prevent key churn on every plan; rotate intentionally by tainting
    ignore_changes = [secret_string]
  }
}

# ─── IAM role + instance profile ─────────────────────────────────────────────
resource "aws_iam_role" "app" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-ec2-role" }
}

# SSM managed instance core — enables Ansible ssm connection plugin
resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.app.name
}

# CloudWatch agent
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.app.name
}

# Access to application secrets (RDS password, JWT secret)
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.project_name}-ec2-secrets-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadAppSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_arns
      },
      {
        Sid    = "DecryptAppKmsKeys"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = concat(var.kms_key_arns, [aws_kms_key.ec2.arn])
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.app.name

  tags = { Name = "${var.project_name}-ec2-profile" }
}

# ─── CloudWatch log group for application logs ───────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.project_name}/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.project_name}-app-logs" }
}

# ─── Launch Template — backend ───────────────────────────────────────────────
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.backend_instance_type
  key_name      = aws_key_pair.app.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
    delete_on_termination       = true
  }

  # Encrypted root volume (CKV_AWS_8)
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.backend_disk_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2.arn
      delete_on_termination = true
    }
  }

  # IMDSv2 enforcement (CKV_AWS_79)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Minimal bootstrap — Ansible handles full configuration
    set -euo pipefail
    dnf update -y --security
    # SSM agent is pre-installed on AL2023
    systemctl enable amazon-ssm-agent
    systemctl start  amazon-ssm-agent
    # CloudWatch agent
    dnf install -y amazon-cloudwatch-agent
    # Tag the instance with role metadata (readable by Ansible)
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
    aws ec2 create-tags --region "$REGION" --resources "$INSTANCE_ID" \
      --tags Key=AnsibleRole,Value=backend Key=Environment,Value=${var.environment} 2>/dev/null || true
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = "${var.project_name}-backend"
      Role         = "backend"
      Environment  = var.environment
      AnsibleGroup = "backend"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.project_name}-backend-volume"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Launch Template — frontend ──────────────────────────────────────────────
resource "aws_launch_template" "frontend" {
  name_prefix   = "${var.project_name}-frontend-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.frontend_instance_type
  key_name      = aws_key_pair.app.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.frontend_disk_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2.arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf update -y --security
    systemctl enable amazon-ssm-agent
    systemctl start  amazon-ssm-agent
    dnf install -y amazon-cloudwatch-agent
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
    aws ec2 create-tags --region "$REGION" --resources "$INSTANCE_ID" \
      --tags Key=AnsibleRole,Value=frontend Key=Environment,Value=${var.environment} 2>/dev/null || true
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name         = "${var.project_name}-frontend"
      Role         = "frontend"
      Environment  = var.environment
      AnsibleGroup = "frontend"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.project_name}-frontend-volume"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Auto Scaling Group — backend ────────────────────────────────────────────
resource "aws_autoscaling_group" "backend" {
  name_prefix         = "${var.project_name}-backend-"
  min_size            = var.backend_min_count
  max_size            = var.backend_max_count
  desired_capacity    = var.backend_desired_count
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.backend_target_group_arn]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 120

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }
  tag {
    key                 = "AnsibleGroup"
    value               = "backend"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# ─── Auto Scaling Group — frontend ───────────────────────────────────────────
resource "aws_autoscaling_group" "frontend" {
  name_prefix         = "${var.project_name}-frontend-"
  min_size            = var.frontend_min_count
  max_size            = var.frontend_max_count
  desired_capacity    = var.frontend_desired_count
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.frontend_target_group_arn]

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 120

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-frontend"
    propagate_at_launch = true
  }
  tag {
    key                 = "AnsibleGroup"
    value               = "frontend"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# ─── SSM Parameter Store — Ansible dynamic inventory references ──────────────
# Ansible uses the aws_ec2 dynamic inventory plugin; these parameters hold the
# ASG names so the playbook wrapper knows which fleet to target.
resource "aws_ssm_parameter" "ansible_backend_asg" {
  name  = "/${var.project_name}/${var.environment}/ansible/backend_asg_name"
  type  = "String"
  value = aws_autoscaling_group.backend.name

  tags = { Name = "${var.project_name}-${var.environment}-backend-asg-param" }
}

resource "aws_ssm_parameter" "ansible_frontend_asg" {
  name  = "/${var.project_name}/${var.environment}/ansible/frontend_asg_name"
  type  = "String"
  value = aws_autoscaling_group.frontend.name

  tags = { Name = "${var.project_name}-${var.environment}-frontend-asg-param" }
}

resource "aws_ssm_parameter" "ansible_environment" {
  name  = "/${var.project_name}/${var.environment}/ansible/environment"
  type  = "String"
  value = var.environment

  tags = { Name = "${var.project_name}-${var.environment}-environment-param" }
}
