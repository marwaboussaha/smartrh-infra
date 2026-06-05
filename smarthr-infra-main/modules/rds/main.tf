# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project}-sg-rds"
  description = "RDS: allow MySQL only from ECS app tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-rds" }
}

# ── RDS Security Group Ingress Rule (separate to avoid circular dependency) ───
resource "aws_security_group_rule" "rds_ingress_from_app" {
  count                    = var.app_sg_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.app_sg_id
  security_group_id        = aws_security_group.rds.id
  description              = "MySQL from ECS app tasks only"
}

# ── DB Subnet Group (spans both AZs) ─────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-db-subnet-group"
  description = "SmartHR RDS subnet group across AZ-A and AZ-B"
  subnet_ids  = var.private_subnet_ids
  tags        = { Name = "${var.project}-db-subnet-group" }
}

# ── Parameter Group ───────────────────────────────────────────────────────────
resource "aws_db_parameter_group" "main" {
  name        = "${var.project}-mysql8"
  family      = "mysql8.0"
  description = "SmartHR MySQL 8.0 parameters"

  # Checkov CKV_AWS_129: general log enabled
  parameter {
    name  = "general_log"
    value = "1"
  }

  tags = { Name = "${var.project}-db-params" }
}

# ── RDS Instance ──────────────────────────────────────────────────────────────
# Checkov CKV_AWS_16:  encryption at rest enabled (storage_encrypted)
# Checkov CKV_AWS_17:  publicly_accessible = false
# Checkov CKV_AWS_118: enhanced monitoring enabled
# Checkov CKV_AWS_133: deletion_protection = true
# Checkov CKV_AWS_157: multi_az = true
# Checkov CKV_AWS_293: auto_minor_version_upgrade = true
resource "aws_db_instance" "main" {
  identifier        = var.project
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 50
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "smarthr"
  username = "smarthr"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = true
  publicly_accessible = false

  backup_retention_period    = 0
  backup_window              = "03:00-04:00"
  maintenance_window         = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade = true

  deletion_protection       = true
  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.project}-final-snapshot"

  performance_insights_enabled = false

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = { Name = "${var.project}-rds" }
}

# ── Enhanced Monitoring Role ──────────────────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project}-rds-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
