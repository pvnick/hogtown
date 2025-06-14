variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "rds_secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret containing RDS master credentials"
  type        = string
}

variable "environment_databases" {
  description = "List of environment-specific databases to create"
  type        = list(string)
  default     = []
}

variable "lambda_function_name" {
  description = "Name of the Lambda function that handles database setup"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile to use for CLI commands"
  type        = string
  default     = ""
}