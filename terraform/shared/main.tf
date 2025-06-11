terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC with private subnets for RDS
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Private Subnets for RDS (3 across different AZs, /28 = 16 IPs each)
resource "aws_subnet" "rds_private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 12, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "${var.project_name}-rds-private-subnet-${count.index + 1}"
    Project = var.project_name
    Type    = "Private"
    Purpose = "RDS"
  }
}

# Shared database infrastructure
module "database" {
  source = "../modules/database"
  
  project_name               = var.project_name
  vpc_id                    = aws_vpc.main.id
  availability_zones        = [for subnet in aws_subnet.rds_private : subnet.availability_zone]
  allowed_security_groups   = var.allowed_security_groups
  allowed_cidr_blocks       = [aws_vpc.main.cidr_block]
  postgres_version          = var.postgres_version
  db_instance_class         = var.db_instance_class
  db_allocated_storage      = var.db_allocated_storage
  db_max_allocated_storage  = var.db_max_allocated_storage
  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_period
  monitoring_interval       = var.monitoring_interval
  performance_insights_enabled = var.performance_insights_enabled
  deletion_protection       = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
}

# GitHub connection (shared across environments)
resource "aws_apprunner_connection" "github" {
  connection_name = "${var.project_name}-github-connection"
  provider_type   = "GITHUB"

  tags = {
    Name    = "${var.project_name}-github-connection"
    Project = var.project_name
  }
}

# Application secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${var.project_name}-app-secrets"
  description = "Application secrets for ${var.project_name}"

  tags = {
    Name    = "${var.project_name}-app-secrets"
    Project = var.project_name
  }
}

# Generate random secret key for Django
resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}

# Application secrets values
resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    # Django application secrets
    SECRET_KEY           = random_password.django_secret_key.result
    PROSOPO_SITE_KEY    = var.prosopo_site_key
    PROSOPO_SECRET_KEY  = var.prosopo_secret_key
    SENDINBLUE_API_KEY  = var.sendinblue_api_key
    DEFAULT_FROM_EMAIL  = var.default_from_email
    ALLOWED_HOSTS       = var.allowed_hosts
    
    # Database connection details
    DB_HOST     = module.database.db_instance_endpoint
    DB_PORT     = tostring(module.database.db_instance_port)
    DB_NAME     = module.database.db_instance_name
    DB_USERNAME = module.database.db_instance_username
    DB_PASSWORD = module.database.db_instance_password
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}