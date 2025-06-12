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

output "app_secrets_arn" {
  description = "The ARN of the application secrets in Secrets Manager"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "app_secrets_name" {
  description = "The name of the application secrets in Secrets Manager"
  value       = aws_secretsmanager_secret.app_secrets.name
}

# VPC outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "rds_private_subnet_ids" {
  description = "The IDs of the RDS private subnets"
  value       = aws_subnet.rds_private[*].id
}

output "rds_private_subnet_cidrs" {
  description = "The CIDR blocks of the RDS private subnets"
  value       = aws_subnet.rds_private[*].cidr_block
}

output "availability_zones" {
  description = "The availability zones used by the subnets"
  value       = aws_subnet.rds_private[*].availability_zone
}

output "github_repository_url" {
  description = "The GitHub repository URL for App Runner"
  value       = var.github_repository_url
}

# AWS SES Infrastructure Outputs
output "ses_user_name" {
  description = "The name of the auto-generated SES IAM user"
  value       = aws_iam_user.ses_user.name
}

output "ses_user_arn" {
  description = "The ARN of the auto-generated SES IAM user"
  value       = aws_iam_user.ses_user.arn
}

output "ses_policy_arn" {
  description = "The ARN of the SES IAM policy"
  value       = aws_iam_policy.ses_policy.arn
}

output "ses_access_key_id" {
  description = "The auto-generated access key ID for SES (sensitive)"
  value       = aws_iam_access_key.ses_user_key.id
  sensitive   = true
}

