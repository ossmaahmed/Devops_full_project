variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type = string
}

variable "access_cidr" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  description = "AWS account ID that stores branch deployment parameters"
  type        = string
}

variable "deployment_role_arns" {
  description = "Exact IAM roles Jenkins is allowed to assume for deployments"
  type        = list(string)
}
