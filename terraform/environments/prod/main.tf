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
    bucket = "hogtown-terraform-state-shared"
    key    = "shared/terraform.tfstate"
    region = "us-east-1"
  }
}

# Database setup for production environment
module "database_setup" {
  source = "../../modules/database-setup"
  
  project_name           = var.project_name
  rds_secrets_manager_arn = data.terraform_remote_state.shared.outputs.secrets_manager_arn
  environment_databases  = ["${var.project_name}_prod"]
}

# Production App Runner service
module "prod_apprunner" {
  source = "../../modules/apprunner"
  
  app_name                    = "${var.project_name}-prod"
  project_name               = var.project_name
  environment                = "prod"
  vpc_id                     = var.vpc_id
  enable_vpc_connector       = var.enable_vpc_connector
  database_security_groups   = [data.terraform_remote_state.shared.outputs.database_security_group_id]
  github_repository_url      = var.github_repository_url
  github_branch              = var.prod_branch
  github_connection_arn      = data.terraform_remote_state.shared.outputs.github_connection_arn
  auto_deploy_enabled        = var.auto_deploy_enabled
  cpu                        = var.prod_cpu
  memory                     = var.prod_memory
  secrets_manager_arns       = [for arn in module.database_setup.environment_database_secrets : arn]
  database_secret_arn        = module.database_setup.environment_database_secrets["${var.project_name}_prod"]
  observability_enabled      = var.observability_enabled
  log_retention_days         = var.log_retention_days
  
  # Health check configuration
  health_check_path          = var.health_check_path
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  health_check_interval      = var.health_check_interval
  health_check_timeout       = var.health_check_timeout
}