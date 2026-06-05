output "web_repository_url" {
  value = aws_ecr_repository.web.repository_url
}

output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "redis_repository_url" {
  value = aws_ecr_repository.redis.repository_url
}

output "agent_repository_url" {
  value = aws_ecr_repository.agent.repository_url
}
