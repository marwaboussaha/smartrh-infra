# ─────────────────────────────────────────────────────────────────────────────
# SmartHR — Route 53 DNS module
#
# Manages:
#   - A record (Alias): smarthr.anesbhd.com → ALB DNS name
# ─────────────────────────────────────────────────────────────────────────────

# ── A Record (Alias) — smarthr.anesbhd.com → ALB ─────────────────────────────
resource "aws_route53_record" "smarthr" {
  zone_id = var.zone_id
  name    = var.app_subdomain
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
