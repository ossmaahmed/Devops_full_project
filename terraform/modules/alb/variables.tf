variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "log_bucket_name" {
  type = string
}

variable "node_group_asg_name" {
  type = string
}

variable "eks_cluster_security_group_id" {
  type = string
}
