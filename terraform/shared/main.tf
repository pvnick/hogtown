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

# Shared database infrastructure
module "database" {
  source = "../modules/database"
  
  project_name               = var.project_name
  vpc_id                    = var.vpc_id
  availability_zones        = var.availability_zones
  allowed_security_groups   = var.allowed_security_groups
  allowed_cidr_blocks       = var.allowed_cidr_blocks
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