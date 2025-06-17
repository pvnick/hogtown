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
  region  = local.config.aws_region
  profile = local.config.aws_profile != "" ? local.config.aws_profile : null
}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC with private subnets for RDS
resource "aws_vpc" "main" {
  cidr_block           = local.config.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${local.config.project_name}-vpc"
    Project = local.config.project_name
  }
}

# Private Subnets for RDS (3 across different AZs, /28 = 16 IPs each)
resource "aws_subnet" "rds_private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.config.vpc_cidr, 12, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "${local.config.project_name}-rds-private-subnet-${count.index + 1}"
    Project = local.config.project_name
    Type    = "Private"
    Purpose = "RDS"
  }
}

# Private Subnets for AppRunner (3 across different AZs, /22 = 1024 IPs each)
resource "aws_subnet" "apprunner_private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.config.vpc_cidr, 6, count.index + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "${local.config.project_name}-apprunner-private-subnet-${count.index + 1}"
    Project = local.config.project_name
    Type    = "Private"
    Purpose = "AppRunner"
  }
}

# Private Subnets for Lambda (3 across different AZs, /24 = 256 IPs each)
resource "aws_subnet" "lambda_private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.config.vpc_cidr, 8, count.index + 16)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name    = "${local.config.project_name}-lambda-private-subnet-${count.index + 1}"
    Project = local.config.project_name
    Type    = "Private"
    Purpose = "Lambda"
  }
}

# Shared database infrastructure
module "database" {
  source = "../modules/database"
  
  project_name               = local.config.project_name
  vpc_id                    = aws_vpc.main.id
  database_subnet_ids       = aws_subnet.rds_private[*].id
  availability_zones        = local.config.availability_zones != [] ? local.config.availability_zones : [for subnet in aws_subnet.rds_private : subnet.availability_zone]
  allowed_cidr_blocks       = aws_subnet.apprunner_private[*].cidr_block
  postgres_version          = local.config.postgres_version
  db_instance_class         = local.config.db_instance_class
  db_allocated_storage      = local.config.db_allocated_storage
  db_max_allocated_storage  = local.config.db_max_allocated_storage
  multi_az                  = local.config.multi_az
  backup_retention_period   = local.config.backup_retention_period
  monitoring_interval       = local.config.monitoring_interval
  performance_insights_enabled = local.config.performance_insights_enabled
  deletion_protection       = local.config.deletion_protection
  skip_final_snapshot      = local.config.skip_final_snapshot
  lambda_subnet_ids        = aws_subnet.lambda_private[*].id
}

# VPC Endpoints for Lambda to access AWS services without internet
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.lambda_private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name    = "${local.config.project_name}-secretsmanager-endpoint"
    Project = local.config.project_name
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.lambda_private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name    = "${local.config.project_name}-logs-endpoint"
    Project = local.config.project_name
  }
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.lambda_private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name    = "${local.config.project_name}-kms-endpoint"
    Project = local.config.project_name
  }
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.config.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.config.project_name}-vpc-endpoints-sg"
    Project = local.config.project_name
  }
}

# Data source for current region
data "aws_region" "current" {}

# GitHub connection (shared across environments)
resource "aws_apprunner_connection" "github" {
  connection_name = "${local.config.project_name}-github-connection"
  provider_type   = "GITHUB"

  tags = {
    Name    = "${local.config.project_name}-github-connection"
    Project = local.config.project_name
  }
}

# Django application configuration in AWS Secrets Manager
resource "aws_secretsmanager_secret" "django_app_config" {
  name        = "${local.config.project_name}-django-app-config"
  description = "Django application configuration and email service credentials for ${local.config.project_name}"

  tags = {
    Name    = "${local.config.project_name}-django-app-config"
    Project = local.config.project_name
  }
}

# Generate random secret key for Django
resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}

# AWS SES Email Infrastructure
# Creates dedicated IAM user with minimal permissions for email sending
# Automatically generates and rotates access keys stored in Secrets Manager

# IAM user for SES email sending (principle of least privilege)
resource "aws_iam_user" "email_service_user" {
  name = "${local.config.project_name}-email-service-user"
  path = "/"

  tags = {
    Name    = "${local.config.project_name}-email-service-user"
    Project = local.config.project_name
    Purpose = "SES Email Sending"
  }
}

# IAM policy with minimal SES permissions (send-only)
resource "aws_iam_policy" "email_sending_policy" {
  name        = "${local.config.project_name}-email-sending-policy"
  description = "Minimal policy for SES email sending - send operations only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendBulkTemplatedEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = local.config.default_from_email
          }
        }
      }
    ]
  })

  tags = {
    Name    = "${local.config.project_name}-email-sending-policy"
    Project = local.config.project_name
  }
}

# Attach SES policy to user
resource "aws_iam_user_policy_attachment" "email_service_user_policy" {
  user       = aws_iam_user.email_service_user.name
  policy_arn = aws_iam_policy.email_sending_policy.arn
}

# Auto-generate access keys for email service user
# Keys are automatically stored in AWS Secrets Manager for secure access
resource "aws_iam_access_key" "email_service_access_key" {
  user = aws_iam_user.email_service_user.name
}

# Django application configuration values
resource "aws_secretsmanager_secret_version" "django_app_config" {
  secret_id = aws_secretsmanager_secret.django_app_config.id
  secret_string = jsonencode({
    # Django application secrets
    SECRET_KEY           = random_password.django_secret_key.result
    PROSOPO_SITE_KEY    = local.config.prosopo_site_key
    PROSOPO_SECRET_KEY  = local.config.prosopo_secret_key
    
    # Email service credentials (auto-generated)
    EMAIL_SERVICE_ACCESS_KEY_ID     = aws_iam_access_key.email_service_access_key.id
    EMAIL_SERVICE_SECRET_ACCESS_KEY = aws_iam_access_key.email_service_access_key.secret
    AWS_REGION           = local.config.aws_region
    DEFAULT_FROM_EMAIL   = local.config.default_from_email
    ALLOWED_HOSTS        = local.config.allowed_hosts
    
    # Database connection details
    DB_HOST     = module.database.database_endpoint
    DB_PORT     = tostring(module.database.database_port)
    DB_NAME     = module.database.database_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
