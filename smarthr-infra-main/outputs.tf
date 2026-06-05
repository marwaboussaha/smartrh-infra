output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "app_url" {
  description = "Application URL"
  value       = "https://${module.dns.smarthr_fqdn}"
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.acm.certificate_arn
}

output "certificate_status" {
  description = "ACM certificate status — should be ISSUED"
  value       = module.acm.certificate_status
}

output "route53_name_servers" {
  description = "Route 53 NS records — update registrar"
  value       = aws_route53_zone.main.name_servers
}

output "web_ecr_repo_url" {
  description = "ECR repository URL for the web container"
  value       = module.ecr.web_repository_url
}

output "backend_ecr_repo_url" {
  description = "ECR repository URL for the backend container"
  value       = module.ecr.backend_repository_url
}

output "redis_ecr_repo_url" {
  description = "ECR repository URL for the redis container"
  value       = module.ecr.redis_repository_url
}

output "agent_ecr_repo_url" {
  description = "ECR repository URL for the agent container"
  value       = module.ecr.agent_repository_url
}
