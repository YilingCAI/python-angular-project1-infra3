output "backend_asg_name" {
  description = "Auto Scaling Group name for backend instances"
  value       = aws_autoscaling_group.backend.name
}

output "frontend_asg_name" {
  description = "Auto Scaling Group name for frontend instances"
  value       = aws_autoscaling_group.frontend.name
}

output "iam_role_arn" {
  description = "IAM role ARN attached to EC2 instances"
  value       = aws_iam_role.app.arn
}

output "iam_instance_profile_arn" {
  description = "IAM instance profile ARN"
  value       = aws_iam_instance_profile.app.arn
}

output "key_pair_name" {
  description = "EC2 key pair name"
  value       = aws_key_pair.app.key_name
}

output "ssh_private_key_secret_arn" {
  description = "Secrets Manager ARN holding the SSH private key (for Ansible via SSH)"
  value       = aws_secretsmanager_secret.ssh_private_key.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for EBS encryption and SSH key secret"
  value       = aws_kms_key.ec2.arn
}

output "ansible_backend_asg_param" {
  description = "SSM Parameter Store path with backend ASG name (for Ansible dynamic inventory)"
  value       = aws_ssm_parameter.ansible_backend_asg.name
}

output "ansible_frontend_asg_param" {
  description = "SSM Parameter Store path with frontend ASG name (for Ansible dynamic inventory)"
  value       = aws_ssm_parameter.ansible_frontend_asg.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for application logs"
  value       = aws_cloudwatch_log_group.app.name
}
