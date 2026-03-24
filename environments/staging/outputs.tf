output "alb_dns_name" {
  description = "ALB DNS name — point your DNS record here"
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
}

output "backend_asg_name" {
  description = "Backend Auto Scaling Group name (used by Ansible dynamic inventory)"
  value       = module.ec2.backend_asg_name
}

output "frontend_asg_name" {
  description = "Frontend Auto Scaling Group name (used by Ansible dynamic inventory)"
  value       = module.ec2.frontend_asg_name
}

output "ec2_iam_role_arn" {
  description = "IAM role ARN attached to EC2 instances"
  value       = module.ec2.iam_role_arn
}

output "ssh_private_key_secret_arn" {
  description = "Secrets Manager ARN for the SSH private key (Ansible via SSH fallback)"
  value       = module.ec2.ssh_private_key_secret_arn
}

output "ansible_backend_asg_param" {
  description = "SSM Parameter path storing the backend ASG name"
  value       = module.ec2.ansible_backend_asg_param
}

output "ansible_frontend_asg_param" {
  description = "SSM Parameter path storing the frontend ASG name"
  value       = module.ec2.ansible_frontend_asg_param
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-dashboard"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for application logs"
  value       = module.ec2.cloudwatch_log_group
}
