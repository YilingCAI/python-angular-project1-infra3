environment  = "prod"
project_name = "mypythonproject1-prod"
aws_region   = "us-east-1"

# Networking
vpc_cidr              = "10.2.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs   = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs  = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
database_subnet_cidrs = ["10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"]
app_port              = 8000
frontend_port         = 4200

# RDS
db_name                  = "gamedb"
db_username              = "postgres"
db_engine_version        = "17.6"
db_instance_class        = "db.t3.medium"
db_allocated_storage     = 100
db_max_allocated_storage = 500
backup_retention_days    = 30
multi_az                 = true
log_retention_days       = 30

# EC2 — backend
backend_instance_type = "t3.large"
backend_disk_size     = 50
backend_desired_count = 3
backend_min_count     = 3
backend_max_count     = 8

# EC2 — frontend
frontend_instance_type = "t3.large"
frontend_disk_size     = 50
frontend_desired_count = 3
frontend_min_count     = 3
frontend_max_count     = 8

# ALB
health_check_path      = "/health"
certificate_arn        = ""   # REQUIRED: Add your ACM certificate ARN for production
alb_enforce_https_only = true # Enforce HTTPS in production

# JWT (provide via CI secret TF_VAR_jwt_secret_key)
# jwt_secret_key = ""
