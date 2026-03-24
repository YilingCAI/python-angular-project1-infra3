variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mypythonproject1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Networking
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "app_port" {
  description = "Application (backend) port"
  type        = number
  default     = 8000
}

variable "frontend_port" {
  description = "Frontend port"
  type        = number
  default     = 4200
}

# RDS
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "gamedb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17.6"
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for auto-scaling"
  type        = number
  default     = 100
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "multi_az" {
  description = "Enable Multi-AZ RDS deployment"
  type        = bool
  default     = true
}

variable "enable_secret_rotation" {
  description = "Enable Secrets Manager automatic rotation resources"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "ebs_kms_key_arn" {
  description = "Optional CMK ARN for EC2 root EBS encryption. Leave empty to use AWS managed EBS key."
  type        = string
  default     = ""
}

# EC2 instance sizing
variable "backend_instance_type" {
  description = "EC2 instance type for backend servers"
  type        = string
  default     = "t3.small"
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend servers"
  type        = string
  default     = "t3.small"
}

variable "backend_disk_size" {
  description = "Root EBS volume size (GB) for backend instances"
  type        = number
  default     = 20
}

variable "frontend_disk_size" {
  description = "Root EBS volume size (GB) for frontend instances"
  type        = number
  default     = 20
}

# Backend Auto Scaling Group
variable "backend_desired_count" {
  description = "Desired number of backend EC2 instances"
  type        = number
  default     = 1
}

variable "backend_min_count" {
  description = "Minimum number of backend EC2 instances"
  type        = number
  default     = 1
}

variable "backend_max_count" {
  description = "Maximum number of backend EC2 instances"
  type        = number
  default     = 3
}

# Frontend Auto Scaling Group
variable "frontend_desired_count" {
  description = "Desired number of frontend EC2 instances"
  type        = number
  default     = 1
}

variable "frontend_min_count" {
  description = "Minimum number of frontend EC2 instances"
  type        = number
  default     = 1
}

variable "frontend_max_count" {
  description = "Maximum number of frontend EC2 instances"
  type        = number
  default     = 3
}

# ALB
variable "health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "alb_enforce_https_only" {
  description = "Enforce HTTPS-only ALB listeners"
  type        = bool
  default     = false
}

variable "alb_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN to associate with the ALB"
  type        = string
  default     = ""
}

# Application secrets
variable "jwt_secret_key" {
  description = "JWT secret key (injected at apply time, never stored in tfvars)"
  type        = string
  sensitive   = true
}

variable "jwt_algorithm" {
  description = "JWT signing algorithm"
  type        = string
  default     = "HS256"
}

variable "jwt_expire_minutes" {
  description = "JWT token expiry in minutes"
  type        = number
  default     = 30
}
