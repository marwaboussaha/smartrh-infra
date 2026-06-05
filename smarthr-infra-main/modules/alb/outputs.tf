output "alb_arn" { value = aws_lb.main.arn }
output "alb_dns_name" { value = aws_lb.main.dns_name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "alb_sg_id" { value = aws_security_group.alb.id }
output "waf_arn" { value = aws_wafv2_web_acl.alb.arn }
output "alb_zone_id" { value = aws_lb.main.zone_id }
