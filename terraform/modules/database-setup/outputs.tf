output "environment_database_secrets" {
  description = "Map of Secrets Manager ARNs for each environment database"
  value = {
    for env in var.environment_databases : env => data.aws_secretsmanager_secret.env_db_secrets[env].arn
  }
}

output "environment_database_names" {
  description = "List of created environment database names"
  value = var.environment_databases
}