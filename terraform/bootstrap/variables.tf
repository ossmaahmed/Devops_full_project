variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for encrypted Terraform state"
  type        = string
}

variable "lock_table_name" {
  type    = string
  default = "nti-devops-terraform-locks"
}
