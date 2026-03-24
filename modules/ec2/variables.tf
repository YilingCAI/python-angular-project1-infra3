variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where EC2 instances are launched"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID attached to EC2 instances (from vpc module)"
  type        = string
}

variable "backend_target_group_arn" {
  description = "ALB target group ARN for backend instances"
  type        = string
}

variable "frontend_target_group_arn" {
  description = "ALB target group ARN for frontend instances"
  type        = string
}

variable "secrets_arns" {
  description = "List of Secrets Manager ARNs the EC2 instance profile can read"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs the EC2 instance profile can decrypt"
  type        = list(string)
  default     = []
}

# ─── Instance sizing ─────────────────────────────────────────────────────────
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

# ─── Backend Auto Scaling Group ────────────────────────────────────────────
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

# ─── Frontend Auto Scaling Group ───────────────────────────────────────────
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

# ─── Observability ───────────────────────────────────────────────────────────
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
