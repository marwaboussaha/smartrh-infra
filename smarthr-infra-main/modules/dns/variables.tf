variable "zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "app_subdomain" {
  description = "Full subdomain for the app (e.g. smarthr.anesbhd.com)"
  type        = string
  default     = "smarthr.anesbhd.com"
}

variable "alb_dns_name" {
  description = "ALB DNS name from the ALB module output"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID (not your Route 53 zone — the ALB's own zone ID)"
  type        = string
}
