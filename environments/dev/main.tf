/**
 * Main Terraform Configuration – EC2 + Ansible
 * Orchestrates all modules: network, RDS, ALB, and EC2 (Ansible-managed)
 */

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }

  backend "s3" {
    encrypt = true
  }
}

data "aws_caller_identity" "current" {}

# Networking
module "network" {
  source = "../../modules/vpc"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  app_port              = var.app_port
  frontend_port         = var.frontend_port
}

# RDS
module "rds" {
  source = "../../modules/rds"

  project_name             = var.project_name
  database_subnet_ids      = module.network.database_subnet_ids
  rds_security_group_id    = module.network.rds_security_group_id
  db_name                  = var.db_name
  db_username              = var.db_username
  db_engine_version        = var.db_engine_version
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  backup_retention_days    = var.backup_retention_days
  multi_az                 = var.multi_az
  log_retention_days       = var.log_retention_days
  enable_secret_rotation   = var.enable_secret_rotation
}

# ALB
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  app_port              = var.app_port
  frontend_port         = var.frontend_port
  health_check_path     = var.health_check_path
  certificate_arn       = var.certificate_arn
  enforce_https_only    = var.alb_enforce_https_only
  web_acl_arn           = var.alb_web_acl_arn
}

# JWT Secret in Secrets Manager (read by EC2 instances via instance profile)
#checkov:skip=CKV2_AWS_57:Rotation is managed externally due to application-specific rotation workflow.
resource "aws_secretsmanager_secret" "jwt_secret" {
  name_prefix             = "${var.project_name}-jwt-secret-"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.id

  tags = {
    Name = "${var.project_name}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    JWT_SECRET_KEY     = var.jwt_secret_key
    JWT_ALGORITHM      = var.jwt_algorithm
    JWT_EXPIRE_MINUTES = var.jwt_expire_minutes
  })
}

# KMS key for application secrets
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-secrets-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# KMS Key Policy — grants EC2 instance role decrypt access (CKV_AWS_33)
resource "aws_kms_key_policy" "secrets" {
  key_id = aws_kms_key.secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager to use the key"
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
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow EC2 instance role to decrypt secrets"
        Effect = "Allow"
        Principal = {
          AWS = module.ec2.iam_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  depends_on = [module.ec2]
}

# EC2 Module — Ansible-managed application instances
module "ec2" {
  source = "../../modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  private_subnet_ids    = module.network.private_subnet_ids
  app_security_group_id = module.network.app_security_group_id
  log_retention_days    = var.log_retention_days

  backend_target_group_arn  = module.alb.target_group_arn
  frontend_target_group_arn = module.alb.frontend_target_group_arn

  backend_instance_type  = var.backend_instance_type
  frontend_instance_type = var.frontend_instance_type
  backend_disk_size      = var.backend_disk_size
  frontend_disk_size     = var.frontend_disk_size

  backend_desired_count  = var.backend_desired_count
  backend_min_count      = var.backend_min_count
  backend_max_count      = var.backend_max_count
  frontend_desired_count = var.frontend_desired_count
  frontend_min_count     = var.frontend_min_count
  frontend_max_count     = var.frontend_max_count

  secrets_arns = [
    module.rds.secret_arn,
    aws_secretsmanager_secret.jwt_secret.arn,
  ]
  kms_key_arns = [
    aws_kms_key.secrets.arn,
    module.rds.kms_key_arn,
  ]

  depends_on = [module.alb]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.ec2.backend_asg_name, { stat = "Average", label = "Backend CPU" }],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.ec2.frontend_asg_name, { stat = "Average", label = "Frontend CPU" }],
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "RDS CPU" }],
            ["AWS/RDS", "DatabaseConnections", { stat = "Average", label = "DB Connections" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Infrastructure Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.alb_dns_name, { stat = "Sum", label = "ALB Requests" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.alb_dns_name, { stat = "Average", label = "Response Time" }]
          ]
          period = 300
          region = var.aws_region
          title  = "ALB Metrics"
        }
      }
    ]
  })
}
