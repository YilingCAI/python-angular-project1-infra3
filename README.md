# mypythonproject1-infra3

Professional DevOps infrastructure project for deploying a full-stack web application on AWS using Terraform and Ansible.

## Project Description

This repository provisions and operates infrastructure for a production-style full-stack application stack:

- Frontend: Angular
- Backend: Python (FastAPI/Flask)
- Web server and reverse proxy: Nginx
- Cloud platform: AWS EC2 behind Application Load Balancer (ALB)
- Infrastructure as Code: Terraform
- Configuration management and deployment: Ansible

The design emphasizes repeatable infrastructure provisioning, environment consistency, secure network boundaries, and scalable EC2-based delivery.

## Architecture Flow

Request flow:

ALB -> EC2 -> Nginx -> Angular frontend + Python backend API

## Architecture Diagram

```text
Internet Users
		 |
		 v
+-------------------------------+
| Application Load Balancer     |
|  - Listeners: 80 / 443        |
|  - TLS termination            |
+---------------+---------------+
								|
								v
+-----------------------------------------------+
| EC2 Auto Scaling Group (private/public model) |
|                                               |
|  +--------------------+                       |
|  | Nginx              |                       |
|  | - Serves Angular   |                       |
|  | - Reverse proxy    |----> Python API       |
|  +--------------------+                       |
+-----------------------------------------------+
								|
								v
				+------------------+
				| AWS RDS Postgres |
				+------------------+
```

## Terraform Structure

Terraform code is organized by reusable modules and environment-specific roots.

### Modules

- modules/ec2: EC2 launch templates, instance configuration, ASG-related compute resources
- modules/alb: ALB, listeners, target groups, and routing
- modules/vpc: network layer (VPC, subnets, route tables, NAT)
- logical security-group layer: implemented through VPC/EC2/ALB module security group resources

### Environment roots

Each environment has its own Terraform root:

- environments/dev
- environments/staging
- environments/prod

Each root contains standard files such as:

- main.tf
- variables.tf
- outputs.tf
- backend.hcl
- terraform.tfvars

## Ansible Structure

Ansible is used for post-provision configuration and application deployment.

### Roles

- ansible/roles/nginx: Nginx installation and reverse-proxy configuration
- ansible/roles/backend: Python runtime and backend service deployment
- ansible/roles/frontend: frontend build/runtime deployment to Nginx-served path

Additional shared/security/ops roles are available for hardening and common setup.

### Playbooks

- ansible/playbooks/deploy.yml: primary deployment workflow
- ansible/playbooks/site.yml: full configuration orchestration
- ansible/playbooks/rollback.yml: rollback procedure

### Inventory

- ansible/inventory/aws_ec2.yml: dynamic inventory from AWS

## Deployment Steps

```bash
# 1) Initialize Terraform (example: staging)
terraform -chdir=environments/staging init

# 2) Review execution plan
terraform -chdir=environments/staging plan

# 3) Apply infrastructure
terraform -chdir=environments/staging apply

# 4) Configure and deploy application with Ansible
ansible-playbook -i ansible/inventory/aws_ec2.yml ansible/playbooks/deploy.yml
```

## Security Groups Model

- ALB security group:
	- Inbound: 80/443 from internet
	- Outbound: application traffic to EC2 target instances
- EC2 security group:
	- Inbound: application port only from ALB security group
	- No direct public access to application ports from internet
- Database security group:
	- Inbound: database port only from application/EC2 security group

This enforces tier isolation and least-privilege network access.

## Scaling Strategy

- Multiple EC2 instances are registered behind ALB target groups.
- Horizontal scaling is achieved by increasing desired capacity in Auto Scaling configuration.
- ALB distributes traffic across healthy instances.
- This model supports rolling updates with reduced downtime risk.

## Tech Stack

- Infrastructure as Code: Terraform
- Configuration management: Ansible
- Cloud: AWS (EC2, ALB, VPC, IAM, CloudWatch, RDS)
- Frontend: Angular
- Backend: Python (FastAPI/Flask)
- Web server: Nginx
- CI/CD: GitHub Actions

## Future Improvements

- Add blue/green or canary deployment strategy for zero-downtime releases.
- Add immutable AMI pipeline (Packer) to reduce configuration drift.
- Integrate WAF and advanced ALB security policies.
- Add autoscaling policies driven by custom metrics.
- Implement centralized observability with dashboards and alerting SLOs.
- Add policy-as-code checks (OPA/Conftest) in CI.
- Add disaster recovery runbooks and regular restore testing.
