output "cluster_name" { value = aws_ecs_cluster.main.name }
output "app_sg_id" { value = aws_security_group.app.id }
output "cache_sg_id" { value = aws_security_group.cache.id }
output "kms_key_arn" { value = aws_kms_key.ecs.arn }
