output "smarthr_fqdn" {
  description = "Full DNS name of the app record"
  value       = aws_route53_record.smarthr.fqdn
}
