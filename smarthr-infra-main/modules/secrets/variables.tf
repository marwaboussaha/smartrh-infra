variable "project" {
  type = string
}

variable "db_host" {
  type      = string
  sensitive = true
}

variable "app_key" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "agent_token" {
  type      = string
  sensitive = true
}

variable "backend_token" {
  type      = string
  sensitive = true
}

variable "openrouter_api_key" {
  type      = string
  sensitive = true
}

variable "openrouter_model" {
  type      = string
  sensitive = true
}
