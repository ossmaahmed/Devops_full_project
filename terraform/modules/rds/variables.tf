variable "project_name" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "allowed_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "backup_retention_period" {
  description = "Automated backup retention in days; 0 disables automated backups"
  type        = number
  default     = 0

  validation {
    condition     = var.backup_retention_period == 0 || (var.backup_retention_period >= 1 && var.backup_retention_period <= 35)
    error_message = "backup_retention_period must be 0 or between 1 and 35 days."
  }
}
