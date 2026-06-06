output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "L'adresse technique de votre Load Balancer"
  value       = module.alb.alb_dns_name
}

output "app_url" {
  description = "URL pour accéder à votre application"
  value       = "http://${module.alb.alb_dns_name}"
}

output "rds_endpoint" {
  description = "Adresse de la base de données"
  value       = module.rds.db_instance_address
}