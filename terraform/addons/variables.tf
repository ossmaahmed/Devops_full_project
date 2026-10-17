variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "nti-devops"
}

variable "application_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "nti-app"
}

variable "cluster_name" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "cluster_oidc_provider_arn" {
  type = string
}

variable "database_secret_arn" {
  type = string
}
