output "db_host_arn" { value = aws_secretsmanager_secret.db_host.arn }
output "app_key_arn" { value = aws_secretsmanager_secret.app_key.arn }
output "db_password_arn" { value = aws_secretsmanager_secret.db_password.arn }
output "agent_token_arn" { value = aws_secretsmanager_secret.agent_token.arn }
output "backend_token_arn" { value = aws_secretsmanager_secret.backend_token.arn }
output "openrouter_api_key_arn" { value = aws_secretsmanager_secret.openrouter_api_key.arn }
output "openrouter_model_arn" { value = aws_secretsmanager_secret.openrouter_model.arn }
