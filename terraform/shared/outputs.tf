output "database_endpoint" {
  description = "The RDS instance endpoint"
  value       = module.database.database_endpoint
}

output "database_port" {
  description = "The RDS instance port"
  value       = module.database.database_port
}

output "database_security_group_id" {
  description = "The RDS security group ID"
  value       = module.database.security_group_id
}

output "secrets_manager_arn" {
  description = "The ARN of the secrets manager secret containing RDS master credentials"
  value       = module.database.secrets_manager_arn
}

output "github_connection_arn" {
  description = "The ARN of the GitHub connection"
  value       = aws_apprunner_connection.github.arn
}

output "github_connection_status" {
  description = "The status of the GitHub connection"
  value       = aws_apprunner_connection.github.status
}