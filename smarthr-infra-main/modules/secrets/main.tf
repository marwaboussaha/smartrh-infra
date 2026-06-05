# ── Secrets Manager — DB_HOST ─────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_host" {
  name                    = "${var.project}/DB_HOST"
  description             = "SmartHR RDS endpoint"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_host" {
  secret_id     = aws_secretsmanager_secret.db_host.id
  secret_string = var.db_host
}

# ── Secrets Manager — APP_KEY ─────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "app_key" {
  name                    = "${var.project}/APP_KEY"
  description             = "Laravel application key"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "app_key" {
  secret_id     = aws_secretsmanager_secret.app_key.id
  secret_string = var.app_key
}

# ── Secrets Manager — DB_PASSWORD ─────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project}/DB_PASSWORD"
  description             = "SmartHR RDS password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# ── Secrets Manager — SMARTHR_AGENT_TOKEN ─────────────────────────────────────
resource "aws_secretsmanager_secret" "agent_token" {
  name                    = "${var.project}/SMARTHR_AGENT_TOKEN"
  description             = "SmartHR agent authentication token"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "agent_token" {
  secret_id     = aws_secretsmanager_secret.agent_token.id
  secret_string = var.agent_token
}

# ── Secrets Manager — SMARTHR_BACKEND_TOKEN ───────────────────────────────────
resource "aws_secretsmanager_secret" "backend_token" {
  name                    = "${var.project}/SMARTHR_BACKEND_TOKEN"
  description             = "Sanctum API token for the agent to authenticate with the backend"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "backend_token" {
  secret_id     = aws_secretsmanager_secret.backend_token.id
  secret_string = var.backend_token
}

# ── Secrets Manager — OPENROUTER_API_KEY ──────────────────────────────────────
resource "aws_secretsmanager_secret" "openrouter_api_key" {
  name                    = "${var.project}/OPENROUTER_API_KEY"
  description             = "OpenRouter API key for LLM routing"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "openrouter_api_key" {
  secret_id     = aws_secretsmanager_secret.openrouter_api_key.id
  secret_string = var.openrouter_api_key
}

# ── Secrets Manager — OPENROUTER_MODEL ────────────────────────────────────────
resource "aws_secretsmanager_secret" "openrouter_model" {
  name                    = "${var.project}/OPENROUTER_MODEL"
  description             = "OpenRouter model identifier used by the agent"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "openrouter_model" {
  secret_id     = aws_secretsmanager_secret.openrouter_model.id
  secret_string = var.openrouter_model
}
