variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment used for resource tags"
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.environment)) && length(var.environment) <= 20
    error_message = "environment must be a lowercase name of at most 20 characters."
  }
}

variable "project_name" {
  description = "Project prefix used in resource names"
  type        = string
  default     = "nti-devops"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.project_name)) && length(var.project_name) <= 50
    error_message = "project_name must be lowercase alphanumeric with optional internal hyphens and be at most 50 characters."
  }
}

variable "application_namespace" {
  description = "Kubernetes namespace for the application and Jenkins deployment access"
  type        = string
  default     = "nti-app"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.application_namespace)) && length(var.application_namespace) <= 63
    error_message = "application_namespace must be a valid lowercase Kubernetes DNS label of at most 63 characters."
  }
}

variable "pipeline_environments" {
  description = "Branch-specific deployment targets and cross-account IAM roles"
  type = map(object({
    aws_region         = string
    role_arn           = string
    cluster_name       = string
    ecr_repository_uri = string
    namespace          = string
    secret_id          = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for branch, target in var.pipeline_environments :
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", branch)) &&
      length(branch) <= 63 &&
      can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$", target.role_arn)) &&
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", target.namespace)) &&
      length(target.namespace) <= 63 &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$", target.cluster_name)) &&
      can(regex("^[a-z0-9-]+$", target.aws_region)) &&
      can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com(\\.cn)?/[a-z0-9._/-]+$", target.ecr_repository_uri)) &&
      can(regex("^[A-Za-z0-9/_+=.@-]+$", target.secret_id))
    ])
    error_message = "Each pipeline environment must use a safe branch name, role ARN, region, cluster, ECR URI, namespace, and secret identifier."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to deploy the subnets in"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "eks_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "eks_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "rds_instance_class" {
  description = "Instance class for the RDS database"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated RDS storage in GiB"
  type        = number
  default     = 20
}

variable "jenkins_ami" {
  description = "Optional Ubuntu AMI override; defaults to the latest Ubuntu 22.04 image in the selected region."
  type        = string
  default     = ""
}

variable "key_name" {
  type    = string
  default = "nti-key"
}

variable "eks_version" {
  type    = string
  default = "1.36"
}

variable "jenkins_access_cidr" {
  description = "Trusted IPv4 CIDR allowed to reach Jenkins SSH and web UI"
  type        = string
  default     = "127.0.0.1/32"
}
