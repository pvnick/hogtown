output "database_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "database_port" {
  description = "The RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "The master database name"
  value       = aws_db_instance.postgres.db_name
}

output "security_group_id" {
  description = "The RDS security group ID"
  value       = aws_security_group.rds.id
}

output "secrets_manager_arn" {
  description = "The ARN of the secrets manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_master.arn
}