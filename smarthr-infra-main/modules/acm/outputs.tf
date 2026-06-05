output "certificate_arn" {
  description = "Validated ACM certificate ARN — pass this to the ALB module"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "certificate_domain" {
  description = "Primary domain on the certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_status" {
  description = "Certificate status — should be ISSUED after apply"
  value       = aws_acm_certificate.main.status
}
