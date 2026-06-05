terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "smarthr-terraform-state"
    key            = "smarthr/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "smarthr-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source      = "./modules/vpc"
  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "secrets" {
  source      = "./modules/secrets"
  project     = var.project
  db_host     = module.rds.db_instance_address
  app_key     = var.app_key
  db_password = var.db_password

  # Agent secrets
  agent_token        = var.agent_token
  backend_token      = var.backend_token
  openrouter_api_key = var.openrouter_api_key
  openrouter_model   = var.openrouter_model

  depends_on = [module.rds]
}

module "rds" {
  source             = "./modules/rds"
  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_password        = var.db_password
  app_sg_id          = ""

  depends_on = [module.vpc]
}

resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.ecs.app_sg_id
  security_group_id        = module.rds.security_group_id
  description              = "MySQL from ECS app tasks"
}

module "ecs" {
  source                 = "./modules/ecs"
  project                = var.project
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_target_group_arn   = module.alb.target_group_arn
  alb_sg_id              = module.alb.alb_sg_id
  db_host_secret_arn     = module.secrets.db_host_arn
  app_key_secret_arn     = module.secrets.app_key_arn
  db_password_secret_arn = module.secrets.db_password_arn
  app_domain             = var.app_domain
  backend_image          = var.backend_image
  web_image              = var.web_image
  redis_image            = var.redis_image
  agent_image            = var.agent_image

  # Agent secret ARNs
  agent_token_secret_arn        = module.secrets.agent_token_arn
  backend_token_secret_arn      = module.secrets.backend_token_arn
  openrouter_api_key_secret_arn = module.secrets.openrouter_api_key_arn
  openrouter_model_secret_arn   = module.secrets.openrouter_model_arn

  depends_on = [module.alb, module.secrets]
}

resource "aws_route53_zone" "main" {
  name = "anesbhd.com"
}

module "dns" {
  source        = "./modules/dns"
  zone_id       = aws_route53_zone.main.zone_id
  app_subdomain = var.app_domain
  alb_dns_name  = module.alb.alb_dns_name
  alb_zone_id   = module.alb.alb_zone_id

  depends_on = [module.alb]
}

module "acm" {
  source        = "./modules/acm"
  project       = var.project
  root_domain   = "anesbhd.com"
  app_subdomain = var.app_domain
  zone_id       = aws_route53_zone.main.zone_id
}
module "alb" {
  source            = "./modules/alb"
  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn

  depends_on = [module.acm]
}

module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}