# Load configuration from YAML file with defaults
locals {
  raw_config = yamldecode(file("${path.module}/../../../config/staging.yaml"))
  
  config = {
    # Basic configuration (required)
    project_name = local.raw_config.project_name
    aws_profile  = try(local.raw_config.aws_profile, "")
    aws_region   = try(local.raw_config.aws_region, "us-east-1")
    
    # Backend configuration (required)
    shared_state_bucket = local.raw_config.shared_state_bucket
    shared_state_key    = local.raw_config.shared_state_key
    shared_state_region = local.raw_config.shared_state_region
    
    # Environment-specific configuration with defaults
    staging_branch      = try(local.raw_config.staging_branch, "develop")
    auto_deploy_enabled = try(local.raw_config.auto_deploy_enabled, true)
    staging_cpu         = try(local.raw_config.staging_cpu, "0.25 vCPU")
    staging_memory      = try(local.raw_config.staging_memory, "0.5 GB")
    observability_enabled = try(local.raw_config.observability_enabled, false)
    log_retention_days  = try(local.raw_config.log_retention_days, 7)
    
    # Health check configuration with defaults
    health_check_path               = try(local.raw_config.health_check_path, "/")
    health_check_healthy_threshold  = try(local.raw_config.health_check_healthy_threshold, 1)
    health_check_unhealthy_threshold = try(local.raw_config.health_check_unhealthy_threshold, 3)
    health_check_interval          = try(local.raw_config.health_check_interval, 10)
    health_check_timeout           = try(local.raw_config.health_check_timeout, 5)
  }
}