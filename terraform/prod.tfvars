aws_region            = "us-east-1"
environment           = "prod"
project_name          = "nti-devops-prod"
application_namespace = "nti-app"

vpc_cidr             = "10.40.0.0/16"
public_subnet_cidrs  = ["10.40.1.0/24", "10.40.3.0/24"]
private_subnet_cidrs = ["10.40.11.0/24", "10.40.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

eks_version                 = "1.36"
eks_desired_size            = 1
eks_min_size                = 1
eks_max_size                = 2
eks_instance_types          = ["t3.micro"]
jenkins_instance_type       = "t3.micro"
rds_instance_class          = "db.t3.micro"
rds_allocated_storage       = 20
rds_backup_retention_period = 0