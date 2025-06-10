terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get shared infrastructure information
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

# Database setup for staging environment
module "database_setup" {
  source = "../../modules/database-setup"
  
  project_name           = var.project_name
  rds_secrets_manager_arn = data.terraform_remote_state.shared.outputs.secrets_manager_arn
  environment_databases  = ["${var.project_name}_staging"]
}

# Staging App Runner service
module "staging_apprunner" {
  source = "../../modules/apprunner"
  
  app_name                    = "${var.project_name}-staging"
  project_name               = var.project_name
  environment                = "staging"
  vpc_id                     = var.vpc_id
  enable_vpc_connector       = var.enable_vpc_connector
  database_security_groups   = [data.terraform_remote_state.shared.outputs.database_security_group_id]
  github_repository_url      = var.github_repository_url
  github_branch              = var.staging_branch
  github_connection_arn      = data.terraform_remote_state.shared.outputs.github_connection_arn
  auto_deploy_enabled        = var.auto_deploy_enabled
  cpu                        = var.staging_cpu
  memory                     = var.staging_memory
  secrets_manager_arns       = [for arn in module.database_setup.environment_database_secrets : arn]
  database_secret_arn        = module.database_setup.environment_database_secrets["${var.project_name}_staging"]
  app_secrets_arn           = data.terraform_remote_state.shared.outputs.app_secrets_arn
  app_secrets_name          = data.terraform_remote_state.shared.outputs.app_secrets_name
  observability_enabled      = var.observability_enabled
  log_retention_days         = var.log_retention_days
  
  # Health check configuration
  health_check_path          = var.health_check_path
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  health_check_interval      = var.health_check_interval
  health_check_timeout       = var.health_check_timeout
}