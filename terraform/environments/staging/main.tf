terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = local.config.aws_region
  profile = local.config.aws_profile != "" ? local.config.aws_profile : null
}

# Get shared infrastructure information
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = local.config.shared_state_bucket
    key    = local.config.shared_state_key
    region = local.config.shared_state_region
  }
}

# Database setup for staging environment
module "database_setup" {
  source = "../../modules/database-setup"
  
  project_name           = local.config.project_name
  rds_secrets_manager_arn = data.terraform_remote_state.shared.outputs.secrets_manager_arn
  environment_databases  = ["${local.config.project_name}_staging"]
}

# Staging App Runner service
module "staging_apprunner" {
  source = "../../modules/apprunner"
  
  app_name                    = "${local.config.project_name}-staging"
  project_name               = local.config.project_name
  environment                = "staging"
  vpc_id                     = data.terraform_remote_state.shared.outputs.vpc_id
  enable_vpc_connector       = true
  database_security_groups   = [data.terraform_remote_state.shared.outputs.database_security_group_id]
  github_repository_url      = data.terraform_remote_state.shared.outputs.github_repository_url
  github_branch              = local.config.staging_branch
  github_connection_arn      = data.terraform_remote_state.shared.outputs.github_connection_arn
  auto_deploy_enabled        = local.config.auto_deploy_enabled
  cpu                        = local.config.staging_cpu
  memory                     = local.config.staging_memory
  secrets_manager_arns       = [for arn in module.database_setup.environment_database_secrets : arn]
  database_secret_arn        = module.database_setup.environment_database_secrets["${local.config.project_name}_staging"]
  app_secrets_arn           = data.terraform_remote_state.shared.outputs.app_secrets_arn
  app_secrets_name          = data.terraform_remote_state.shared.outputs.app_secrets_name
  observability_enabled      = local.config.observability_enabled
  log_retention_days         = local.config.log_retention_days
  
  # Health check configuration
  health_check_path          = local.config.health_check_path
  health_check_healthy_threshold   = local.config.health_check_healthy_threshold
  health_check_unhealthy_threshold = local.config.health_check_unhealthy_threshold
  health_check_interval      = local.config.health_check_interval
  health_check_timeout       = local.config.health_check_timeout
}