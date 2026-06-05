# ── Data Source for Current AWS Account ───────────────────────────────────────
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ── KMS Key for Encryption ────────────────────────────────────────────────────
resource "aws_kms_key" "ecs" {
  description             = "KMS key for ECS CloudWatch logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "ecs" {
  name          = "alias/${var.project}-ecs"
  target_key_id = aws_kms_key.ecs.key_id
}

# ── KMS Key Policy for CloudWatch Logs ─────────────────────────────────────────
resource "aws_kms_key_policy" "ecs" {
  key_id = aws_kms_key.ecs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.project}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.ecs.arn
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = var.project

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

# ── Security Groups ───────────────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.project}-sg-app"
  description = "ECS app tasks: allow :80 from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    description = "Allow all outbound (ECR pull, RDS, Redis, Secrets Manager)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-app" }
}

resource "aws_security_group" "cache" {
  name        = "${var.project}-sg-cache"
  description = "Redis: allow :6379 from ECS app tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from ECS app tasks only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-cache" }
}


# ── IAM Execution Role ────────────────────────────────────────────────────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_base" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager access — required because task def uses secrets: []
resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "${var.project}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        var.db_host_secret_arn,
        var.app_key_secret_arn,
        var.db_password_secret_arn,
        var.agent_token_secret_arn,
        var.backend_token_secret_arn,
        var.openrouter_api_key_secret_arn,
        var.openrouter_model_secret_arn
      ]
    }]
  })
}

# ── IAM Task Role ─────────────────────────────────────────────────────────────
resource "aws_iam_role" "ecs_monitoring" {
  name = "${var.project}-ecs-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_monitoring_permissions" {
  name = "${var.project}-ecs-monitoring-policy"
  role = aws_iam_role.ecs_monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.main.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.ecs.arn
      }
    ]
  })
}

# ── Service Connect Namespace ─────────────────────────────────────────────────
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project}.local"
  description = "Service Connect namespace for SmartHR"
  vpc         = var.vpc_id
}

# ── Cache Task Definition ─────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "cache" {
  family                   = "${var.project}-taskdef-cache"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_monitoring.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = "${var.project}-cache"
    image     = var.redis_image
    cpu       = 512
    memory    = 512
    essential = true

    portMappings = [{
      name          = "${var.project}-redis"
      containerPort = 6379
      hostPort      = 6379
      protocol      = "tcp"
    }]

    environment = []

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "cache"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "redis-cli ping || exit 1"]
      interval    = 10
      timeout     = 5
      retries     = 5
      startPeriod = 10
    }
  }])
}

# ── App Task Definition ───────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-taskdef-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "4096"
  memory                   = "16384"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_monitoring.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "${var.project}-backend"
      image     = var.backend_image
      cpu       = 2048
      memory    = 4096
      essential = true

      portMappings = [{
        name          = "${var.project}-backend"
        containerPort = 9000
        hostPort      = 9000
        protocol      = "tcp"
      }]

      environment = [
        { name = "REDIS_HOST", value = "${var.project}-redis" },
        { name = "APP_ENV", value = "production" },
        { name = "DB_USERNAME", value = "smarthr" },
        { name = "REDIS_PORT", value = "6379" },
        { name = "DB_PORT", value = "3306" },
        { name = "REDIS_CLIENT", value = "phpredis" },
        { name = "APP_NAME", value = "Smarthr" },
        { name = "PHP_OPCACHE_VALIDATE_TIMESTAMPS", value = "0" },
        { name = "REDIS_PASSWORD", value = "" },
        { name = "APP_URL", value = "https://${var.app_domain}" },
        { name = "APP_DEBUG", value = "false" },
        { name = "DB_DATABASE", value = "smarthr" }
      ]

      secrets = [
        { name = "DB_HOST", valueFrom = var.db_host_secret_arn },
        { name = "APP_KEY", valueFrom = var.app_key_secret_arn },
        { name = "DB_PASSWORD", valueFrom = var.db_password_secret_arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "backend"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "kill -0 1 || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 10
        startPeriod = 90
      }
    },
    {
      name      = "${var.project}-web"
      image     = var.web_image
      cpu       = 512
      memory    = 1024
      essential = true

      portMappings = [{
        name          = "${var.project}-web"
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = []

      dependsOn = [{
        containerName = "${var.project}-backend"
        condition     = "HEALTHY"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "web"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    },
    {
      name      = "${var.project}-agent"
      image     = var.agent_image
      cpu       = 512
      memory    = 1024
      essential = false

      portMappings = [{
        name          = "${var.project}-agent"
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [
        { name = "ENABLE_LLM_ROUTER", value = "true" },
        { name = "SMARTHR_BACKEND_URL", value = "http://127.0.0.1:80" },
        { name = "REDIS_HOST", value = "${var.project}-redis" },
        { name = "REDIS_PORT", value = "6379" }
      ]

      secrets = [
        { name = "SMARTHR_AGENT_TOKEN", valueFrom = var.agent_token_secret_arn },
        { name = "SMARTHR_BACKEND_TOKEN", valueFrom = var.backend_token_secret_arn },
        { name = "OPENROUTER_API_KEY", valueFrom = var.openrouter_api_key_secret_arn },
        { name = "OPENROUTER_MODEL", valueFrom = var.openrouter_model_secret_arn }
      ]

      dependsOn = [{
        containerName = "${var.project}-backend"
        condition     = "HEALTHY"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "agent"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://127.0.0.1:8080/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 120
      }
    }
  ])
}

# ── Cache ECS Service ─────────────────────────────────────────────────────────
resource "aws_ecs_service" "cache" {
  name                   = "${var.project}-cache-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.cache.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = false

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.cache.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.main.arn

    service {
      port_name      = "${var.project}-redis"
      discovery_name = "${var.project}-redis"
      client_alias {
        port     = 6379
        dns_name = "${var.project}-redis"
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "service-connect-cache"
      }
    }
  }
}

# ── App ECS Service ───────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name                   = "${var.project}-app-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.app.arn
  desired_count          = 2
  launch_type            = "FARGATE"
  enable_execute_command = false

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "${var.project}-web"
    container_port   = 80
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.main.arn

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "service-connect-app"
      }
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_ecs_service.cache]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ── Auto Scaling ──────────────────────────────────────────────────────────────
resource "aws_appautoscaling_target" "app_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "app_memory_policy" {
  name               = "${var.project}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app_target.resource_id
  scalable_dimension = aws_appautoscaling_target.app_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

