variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type        = string
  default     = ""
  description = "Optional: ECS app security group ID (if not provided, security group rule must be created separately)"
}

variable "db_password" {
  type      = string
  sensitive = true
}
