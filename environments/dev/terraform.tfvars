environment  = "dev"
project_name = "mypythonproject1-dev"
aws_region   = "us-east-1"

# Networking
vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
app_port              = 8000
frontend_port         = 80

# RDS
db_name                  = "gamedb"
db_username              = "postgres"
db_engine_version        = "17.6"
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 100
backup_retention_days    = 7
multi_az                 = false # Single-AZ saves cost in dev
log_retention_days       = 3

# EC2 — backend
backend_instance_type = "t3.small"
backend_disk_size     = 20
backend_desired_count = 1
backend_min_count     = 1
backend_max_count     = 2

# EC2 — frontend
frontend_instance_type = "t3.small"
frontend_disk_size     = 20
frontend_desired_count = 1
frontend_min_count     = 1
frontend_max_count     = 2

# ALB
health_check_path = "/health/"
backend_path_patterns = ["/health", "/health/*", "/docs", "/docs/*", "/redoc", "/redoc/*", "/openapi.json", "/api/*", "/users", "/users/*", "/games", "/games/*"]
certificate_arn   = ""

# JWT (provide via: terraform apply -var jwt_secret_key="..." or CI secret)
# jwt_secret_key = ""
