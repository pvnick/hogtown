# Load configuration from YAML file with defaults
locals {
  raw_config = yamldecode(file("${path.module}/../config/shared.yaml"))
  
  config = {
    # Basic configuration (required)
    project_name           = local.raw_config.project_name
    aws_profile           = try(local.raw_config.aws_profile, "")
    aws_region            = try(local.raw_config.aws_region, "us-east-1")
    github_repository_url = local.raw_config.github_repository_url
    
    # VPC Configuration with defaults
    vpc_cidr                = try(local.raw_config.vpc_cidr, "10.0.0.0/16")
    availability_zones      = try(local.raw_config.availability_zones, [])
    
    # Database configuration with defaults
    postgres_version             = try(local.raw_config.postgres_version, "17.4")
    db_instance_class           = try(local.raw_config.db_instance_class, "db.t4g.micro")
    db_allocated_storage        = try(local.raw_config.db_allocated_storage, 20)
    db_max_allocated_storage    = try(local.raw_config.db_max_allocated_storage, 1000)
    multi_az                    = try(local.raw_config.multi_az, false)
    backup_retention_period     = try(local.raw_config.backup_retention_period, 7)
    monitoring_interval         = try(local.raw_config.monitoring_interval, 0)
    performance_insights_enabled = try(local.raw_config.performance_insights_enabled, false)
    deletion_protection         = try(local.raw_config.deletion_protection, true)
    skip_final_snapshot        = try(local.raw_config.skip_final_snapshot, false)
    
    # Application secrets (required)
    prosopo_site_key   = local.raw_config.prosopo_site_key
    prosopo_secret_key = local.raw_config.prosopo_secret_key
    default_from_email = local.raw_config.default_from_email
    allowed_hosts      = local.raw_config.allowed_hosts
  }
}