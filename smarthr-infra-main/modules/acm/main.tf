# ─────────────────────────────────────────────────────────────────────────────
# SmartHR — ACM Certificate module
#
# Creates:
#   - TLS certificate for smarthr.anesbhd.com (+ wildcard *.anesbhd.com)
#   - DNS validation records in Route 53 automatically
#   - Waits for certificate to be ISSUED before returning
#
# This replaces the manually created certificate — import it or let
# Terraform create a new one.
#
# Import existing cert:
#   terraform import module.acm.aws_acm_certificate.main \
#     arn:aws:acm:us-east-1:668216279959:certificate/YOUR-CERT-ID
# ─────────────────────────────────────────────────────────────────────────────

# ── Certificate Request ───────────────────────────────────────────────────────
resource "aws_acm_certificate" "main" {
  domain_name = var.app_subdomain

  # Also cover the root domain and any future subdomains
  subject_alternative_names = [
    var.root_domain,
    "*.${var.root_domain}"
  ]

  validation_method = "DNS"

  # Must recreate before destroying to avoid ALB listener downtime
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-certificate"
  }
}

# ── DNS Validation Records ────────────────────────────────────────────────────
# Terraform reads the CNAME records ACM needs, creates them in Route 53,
# then ACM automatically validates and issues the certificate.
# for_each handles the case where domain_name + SANs need separate records.
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# ── Wait for certificate to be ISSUED ────────────────────────────────────────
# Blocks terraform apply until ACM confirms the cert is valid.
# Typically takes 30-60 seconds after DNS records propagate.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}
