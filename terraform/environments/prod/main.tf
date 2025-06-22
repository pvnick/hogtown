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
    bucket  = local.config.shared_state_bucket
    key     = local.config.shared_state_key
    region  = local.config.shared_state_region
    profile = local.config.aws_profile != "" ? local.config.aws_profile : null
  }
}

# Database setup for production environment
module "database_setup" {
  source = "../../modules/database-setup"
  
  project_name            = local.config.project_name
  rds_secrets_manager_arn = data.terraform_remote_state.shared.outputs.secrets_manager_arn
  environment_databases   = ["${local.config.project_name}_prod"]
  lambda_function_name    = data.terraform_remote_state.shared.outputs.lambda_function_name
  aws_profile            = local.config.aws_profile
}

# Production App Runner service
module "prod_apprunner" {
  source = "../../modules/apprunner"
  
  app_name                    = "${local.config.project_name}-prod"
  project_name               = local.config.project_name
  environment                = "prod"
  vpc_id                     = data.terraform_remote_state.shared.outputs.vpc_id
  enable_vpc_connector       = true
  subnet_ids                 = data.terraform_remote_state.shared.outputs.apprunner_private_subnet_ids
  database_security_groups   = [data.terraform_remote_state.shared.outputs.database_security_group_id]
  ecr_repository_url         = data.terraform_remote_state.shared.outputs.ecr_repository_url
  image_tag                  = "latest"
  auto_deploy_enabled        = local.config.auto_deploy_enabled
  cpu                        = local.config.prod_cpu
  memory                     = local.config.prod_memory
  secrets_manager_arns       = [for arn in module.database_setup.environment_database_secrets : arn]
  database_secret_arn        = module.database_setup.environment_database_secrets["${local.config.project_name}_prod"]
  app_secrets_arn           = data.terraform_remote_state.shared.outputs.django_app_config_arn
  app_secrets_name          = data.terraform_remote_state.shared.outputs.django_app_config_name
  observability_enabled      = local.config.observability_enabled
  log_retention_days         = local.config.log_retention_days
  
  # Health check configuration
  health_check_path          = local.config.health_check_path
  health_check_healthy_threshold   = local.config.health_check_healthy_threshold
  health_check_unhealthy_threshold = local.config.health_check_unhealthy_threshold
  health_check_interval      = local.config.health_check_interval
  health_check_timeout       = local.config.health_check_timeout
  
  # Custom domain configuration
  custom_domain_name    = data.terraform_remote_state.shared.outputs.domain_name
  ssl_certificate_arn   = data.terraform_remote_state.shared.outputs.ssl_certificate_arn
  hosted_zone_id        = data.terraform_remote_state.shared.outputs.hosted_zone_id
}

# Outputs for DNS configuration
output "production_dns_configuration" {
  description = "DNS configuration required for production environment"
  value = {
    domain_name = module.prod_apprunner.custom_domain_name
    record_type = "CNAME"
    record_value = module.prod_apprunner.dns_target
    instructions = "Create a CNAME record in your external DNS provider with the above values"
  }
}