output "staging_app_url" {
  description = "The URL of the staging App Runner service"
  value       = module.staging_apprunner.app_runner_service_url
}

output "staging_app_arn" {
  description = "The ARN of the staging App Runner service"
  value       = module.staging_apprunner.app_runner_service_arn
}

output "staging_app_status" {
  description = "The status of the staging App Runner service"
  value       = module.staging_apprunner.app_runner_service_status
}

output "staging_database_secrets" {
  description = "Secrets Manager ARNs for staging database credentials"
  value       = module.database_setup.environment_database_secrets
  sensitive   = true
}

output "staging_log_group" {
  description = "CloudWatch log group for staging App Runner service"
  value       = module.staging_apprunner.log_group_name
}