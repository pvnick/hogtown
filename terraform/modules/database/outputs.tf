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

output "database_identifier" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.postgres.identifier
}

output "security_group_id" {
  description = "The RDS security group ID"
  value       = aws_security_group.rds.id
}

output "secrets_manager_arn" {
  description = "The ARN of the secrets manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_master.arn
}

output "lambda_function_arn" {
  description = "ARN of the database setup Lambda function"
  value = aws_lambda_function.db_setup.arn
}

output "lambda_function_name" {
  description = "Name of the database setup Lambda function"
  value = aws_lambda_function.db_setup.function_name
}

output "lambda_security_group_id" {
  description = "Security group ID of the Lambda database setup function"
  value       = aws_security_group.lambda_db_setup.id
}
