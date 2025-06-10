terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.0"
    }
  }
}

# Get RDS credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = var.rds_secrets_manager_arn
}

locals {
  rds_creds = jsondecode(data.aws_secretsmanager_secret_version.rds_master.secret_string)
}

# PostgreSQL provider for creating databases and users
provider "postgresql" {
  host     = local.rds_creds.endpoint
  port     = local.rds_creds.port
  database = local.rds_creds.dbname
  username = local.rds_creds.username
  password = local.rds_creds.password
  sslmode  = "require"
}

# Create environment-specific databases
resource "postgresql_database" "env_databases" {
  for_each = toset(var.environment_databases)
  name     = each.value
  
  depends_on = [
    data.aws_secretsmanager_secret_version.rds_master
  ]
}

# Create environment-specific users with strong passwords
resource "random_password" "env_passwords" {
  for_each = toset(var.environment_databases)
  length   = 32
  special  = true
}

resource "postgresql_role" "env_users" {
  for_each = toset(var.environment_databases)
  name     = "${each.value}_user"
  login    = true
  password = random_password.env_passwords[each.key].result
  
  depends_on = [
    postgresql_database.env_databases
  ]
}

# Grant comprehensive privileges to environment users
resource "postgresql_grant" "env_user_database_privileges" {
  for_each    = toset(var.environment_databases)
  database    = postgresql_database.env_databases[each.key].name
  role        = postgresql_role.env_users[each.key].name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE", "TEMPORARY"]
}

# Grant schema privileges
resource "postgresql_grant" "env_user_schema_privileges" {
  for_each    = toset(var.environment_databases)
  database    = postgresql_database.env_databases[each.key].name
  role        = postgresql_role.env_users[each.key].name
  schema      = "public"
  object_type = "schema"
  privileges  = ["CREATE", "USAGE"]
}

# Store environment database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "env_db_secrets" {
  for_each    = toset(var.environment_databases)
  name        = "${var.project_name}/database/${each.value}"
  description = "Database credentials for ${each.value} environment"
  
  tags = {
    Name        = "${var.project_name}-${each.value}-db"
    Environment = each.value
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "env_db_secrets" {
  for_each  = toset(var.environment_databases)
  secret_id = aws_secretsmanager_secret.env_db_secrets[each.key].id
  secret_string = jsonencode({
    username = postgresql_role.env_users[each.key].name
    password = random_password.env_passwords[each.key].result
    endpoint = local.rds_creds.endpoint
    port     = local.rds_creds.port
    dbname   = postgresql_database.env_databases[each.key].name
    database_url = "postgresql://${postgresql_role.env_users[each.key].name}:${random_password.env_passwords[each.key].result}@${local.rds_creds.endpoint}:${local.rds_creds.port}/${postgresql_database.env_databases[each.key].name}"
  })
}