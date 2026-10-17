variable "project_name" {
  type = string
}

variable "aws_region" {
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

variable "chart_version" {
  type    = string
  default = "0.17.0"
}
