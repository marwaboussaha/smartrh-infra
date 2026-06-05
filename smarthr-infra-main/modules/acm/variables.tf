variable "project" {
  description = "Project name"
  type        = string
}

variable "root_domain" {
  description = "Root domain (e.g. anesbhd.com)"
  type        = string
  default     = "anesbhd.com"
}

variable "app_subdomain" {
  description = "App subdomain (e.g. smarthr.anesbhd.com)"
  type        = string
  default     = "smarthr.anesbhd.com"
}

variable "zone_id" {
  description = "Route 53 hosted zone ID — from the dns module output"
  type        = string
}
