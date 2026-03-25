environment  = "staging"
project_name = "mypythonproject1-staging"
aws_region   = "us-east-1"

# Networking
vpc_cidr              = "10.1.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs  = ["10.1.10.0/24", "10.1.11.0/24"]
database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]
app_port              = 8000
frontend_port         = 80

# RDS
db_name                  = "gamedb"
db_username              = "postgres"
db_engine_version        = "17.6"
db_instance_class        = "db.t3.small"
db_allocated_storage     = 50
db_max_allocated_storage = 200
backup_retention_days    = 15
multi_az                 = true
log_retention_days       = 7

# EC2 — backend
backend_instance_type = "t3.medium"
backend_disk_size     = 20
backend_desired_count = 2
backend_min_count     = 2
backend_max_count     = 4

# EC2 — frontend
frontend_instance_type = "t3.medium"
frontend_disk_size     = 20
frontend_desired_count = 2
frontend_min_count     = 2
frontend_max_count     = 4

# ALB
health_check_path = "/health/"
backend_path_patterns = ["/health", "/health/*", "/docs", "/docs/*", "/redoc", "/redoc/*", "/openapi.json", "/api/*", "/users", "/users/*", "/games", "/games/*"]
certificate_arn   = "" # Add your ACM certificate ARN here

# JWT (provide via CI secret TF_VAR_jwt_secret_key)
# jwt_secret_key = ""
