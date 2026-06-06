variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }

variable "certificate_arn" {
  description = "ARN of the ACM certificate (Optional for HTTP only)"
  type        = string
  default     = ""  # <--- TRÈS IMPORTANT : Permet de ne pas remplir l'argument
}