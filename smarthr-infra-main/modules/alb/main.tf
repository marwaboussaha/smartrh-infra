# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project}-sg-alb"
  description = "ALB: allow HTTP inbound"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP inbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-alb" }
}

# ── ALB ───────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project}-alb-access-logs-${var.environment}" # Ajout env pour unicité
  force_destroy = true
}

resource "aws_lb" "main" {
  name                       = "${var.project}-alb"
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = { Name = "${var.project}-alb" }
}

# ── Target Group ──────────────────────────────────────────────────────────────
resource "aws_lb_target_group" "app" {
  name        = "${var.project}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/up"
    protocol            = "HTTP"
    matcher             = "200-302"
  }
}

# ── Listeners (MODIFIÉ : Port 80 uniquement) ──────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# LE BLOC HTTPS (443) A ÉTÉ SUPPRIMÉ