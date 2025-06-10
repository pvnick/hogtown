output "prod_app_url" {
  description = "The URL of the production App Runner service"
  value       = module.prod_apprunner.app_runner_service_url
}

output "prod_app_arn" {
  description = "The ARN of the production App Runner service"
  value       = module.prod_apprunner.app_runner_service_arn
}

output "prod_app_status" {
  description = "The status of the production App Runner service"
  value       = module.prod_apprunner.app_runner_service_status
}

output "prod_database_secrets" {
  description = "Secrets Manager ARNs for production database credentials"
  value       = module.database_setup.environment_database_secrets
  sensitive   = true
}

output "prod_log_group" {
  description = "CloudWatch log group for production App Runner service"
  value       = module.prod_apprunner.log_group_name
}