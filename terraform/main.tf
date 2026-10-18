data "aws_ami" "jenkins_ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_key_pair" "jenkins" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.jenkins_public_key_path))

  tags = {
    Name    = var.key_name
    Project = var.project_name
  }
}

module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = "${var.project_name}-eks"
  subnet_ids      = module.network.private_subnet_ids
  cluster_version = var.eks_version
  desired_size    = var.eks_desired_size
  min_size        = var.eks_min_size
  max_size        = var.eks_max_size
  instance_types  = var.eks_instance_types

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  db_name                 = var.db_name
  db_username             = var.db_username
  subnet_ids              = module.network.private_subnet_ids
  vpc_id                  = module.network.vpc_id
  allowed_cidr            = var.vpc_cidr
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  backup_retention_period = var.rds_backup_retention_period
}

module "jenkins" {
  source = "./modules/jenkins"

  project_name         = var.project_name
  aws_region           = var.aws_region
  aws_account_id       = data.aws_caller_identity.current.account_id
  deployment_role_arns = distinct([for target in values(var.pipeline_environments) : target.role_arn])
  vpc_id               = module.network.vpc_id
  subnet_id            = module.network.public_subnet_ids[0]
  ami_id               = var.jenkins_ami != "" ? var.jenkins_ami : data.aws_ami.jenkins_ubuntu.id
  instance_type        = var.jenkins_instance_type
  key_name             = aws_key_pair.jenkins.key_name
  access_cidr          = var.jenkins_access_cidr
}

module "backup" {
  source = "./modules/backup"

  project_name = var.project_name
  instance_arn = module.jenkins.instance_arn
}

resource "random_id" "bucket" {
  byte_length = 4
}

module "s3_logs" {
  source = "./modules/s3"

  bucket_name = "${var.project_name}-alb-logs-${random_id.bucket.hex}"
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-app"
}

module "alb" {
  source = "./modules/alb"

  project_name                  = var.project_name
  vpc_id                        = module.network.vpc_id
  subnet_ids                    = module.network.public_subnet_ids
  log_bucket_name               = module.s3_logs.bucket_name
  node_group_asg_name           = module.eks.node_group_asg_name
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "jenkins_public_ip" {
  value = module.jenkins.public_ip
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "jenkins_private_ip" {
  value = module.jenkins.private_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "aws_region" {
  value = var.aws_region
}

output "project_name" {
  value = var.project_name
}

output "application_namespace" {
  value = var.application_namespace
}

output "eks_cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_oidc_provider_arn" {
  value = module.eks.cluster_oidc_provider_arn
}

output "rds_secret_arn" {
  value = module.rds.secret_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}
