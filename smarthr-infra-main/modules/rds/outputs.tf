output "endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}

output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "security_group_id" {
  value       = aws_security_group.rds.id
  description = "RDS security group ID for linking to other security groups"
}

output "db_instance_address" {
  value = aws_db_instance.main.endpoint
}
