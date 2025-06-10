output "environment_database_secrets" {
  description = "Map of Secrets Manager ARNs for each environment database"
  value = {
    for env in var.environment_databases : env => aws_secretsmanager_secret.env_db_secrets[env].arn
  }
}

output "database_urls" {
  description = "Complete database URLs for each environment"
  value = {
    for env in var.environment_databases : env => 
      "postgresql://${postgresql_role.env_users[env].name}:${random_password.env_passwords[env].result}@${local.rds_creds.endpoint}:${local.rds_creds.port}/${postgresql_database.env_databases[env].name}"
  }
  sensitive = true
}