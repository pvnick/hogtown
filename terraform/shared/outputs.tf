output "database_endpoint" {
  description = "The RDS instance endpoint"
  value       = module.database.database_endpoint
}

output "database_port" {
  description = "The RDS instance port"
  value       = module.database.database_port
}

output "database_identifier" {
  description = "The RDS instance identifier"
  value       = module.database.database_identifier
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

output "django_app_config_arn" {
  description = "The ARN of the Django application configuration in Secrets Manager"
  value       = aws_secretsmanager_secret.django_app_config.arn
}

output "django_app_config_name" {
  description = "The name of the Django application configuration in Secrets Manager"
  value       = aws_secretsmanager_secret.django_app_config.name
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

output "apprunner_private_subnet_ids" {
  description = "The IDs of the AppRunner private subnets"
  value       = aws_subnet.apprunner_private[*].id
}

output "apprunner_private_subnet_cidrs" {
  description = "The CIDR blocks of the AppRunner private subnets"
  value       = aws_subnet.apprunner_private[*].cidr_block
}

output "lambda_private_subnet_ids" {
  description = "The IDs of the Lambda private subnets"
  value       = aws_subnet.lambda_private[*].id
}

output "lambda_private_subnet_cidrs" {
  description = "The CIDR blocks of the Lambda private subnets"
  value       = aws_subnet.lambda_private[*].cidr_block
}

output "availability_zones" {
  description = "The availability zones used by the subnets"
  value       = aws_subnet.rds_private[*].availability_zone
}

output "github_repository_url" {
  description = "The GitHub repository URL for App Runner"
  value       = local.config.github_repository_url
}

# Email Service Infrastructure Outputs
output "email_service_user_name" {
  description = "The name of the auto-generated email service IAM user"
  value       = aws_iam_user.email_service_user.name
}

output "email_service_user_arn" {
  description = "The ARN of the auto-generated email service IAM user"
  value       = aws_iam_user.email_service_user.arn
}

output "email_sending_policy_arn" {
  description = "The ARN of the email sending IAM policy"
  value       = aws_iam_policy.email_sending_policy.arn
}

output "email_service_access_key_id" {
  description = "The auto-generated access key ID for email service (sensitive)"
  value       = aws_iam_access_key.email_service_access_key.id
  sensitive   = true
}

# Lambda function outputs for database setup
output "lambda_function_arn" {
  description = "ARN of the database setup Lambda function"
  value       = module.database.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the database setup Lambda function"
  value       = module.database.lambda_function_name
}

output "lambda_security_group_id" {
  description = "Security group ID of the Lambda database setup function"
  value       = module.database.lambda_security_group_id
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.hogtown_app.repository_url
  description = "URL of the ECR repository"
}

output "ecr_repository_arn" {
  value       = aws_ecr_repository.hogtown_app.arn
  description = "ARN of the ECR repository"
}

# ECR CI/CD User Outputs
output "ecr_push_user_name" {
  description = "The name of the auto-generated ECR push IAM user"
  value       = aws_iam_user.ecr_push_user.name
}

output "ecr_push_user_arn" {
  description = "The ARN of the auto-generated ECR push IAM user"
  value       = aws_iam_user.ecr_push_user.arn
}

output "ecr_push_credentials_secret_arn" {
  description = "The ARN of the secret containing ECR push credentials"
  value       = aws_secretsmanager_secret.ecr_push_credentials.arn
}

output "ecr_push_credentials_secret_name" {
  description = "The name of the secret containing ECR push credentials"
  value       = aws_secretsmanager_secret.ecr_push_credentials.name
}

output "ecr_push_access_key_id" {
  description = "The auto-generated access key ID for ECR push (sensitive)"
  value       = aws_iam_access_key.ecr_push_access_key.id
  sensitive   = true
}

# Domain and Certificate Outputs
output "domain_name" {
  description = "The custom domain name"
  value       = local.config.domain_name
}

output "hosted_zone_id" {
  description = "The Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_name_servers" {
  description = "The Route 53 hosted zone name servers - point your domain registrar to these"
  value       = aws_route53_zone.main.name_servers
}

output "ssl_certificate_arn" {
  description = "The ARN of the validated SSL certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

# Static Files S3 and CloudFront Outputs
output "static_files_bucket_name" {
  description = "The name of the S3 bucket for static files"
  value       = aws_s3_bucket.static_files.bucket
}

output "static_files_bucket_arn" {
  description = "The ARN of the S3 bucket for static files"
  value       = aws_s3_bucket.static_files.arn
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_files.id
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_files.domain_name
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_files.arn
}

output "static_files_cdn_url" {
  description = "The CDN URL for static files"
  value       = "https://static.${local.config.domain_name}"
}

output "django_s3_user_name" {
  description = "The name of the Django S3 IAM user"
  value       = aws_iam_user.django_s3_user.name
}

output "django_s3_user_arn" {
  description = "The ARN of the Django S3 IAM user"
  value       = aws_iam_user.django_s3_user.arn
}

output "django_s3_access_key_id" {
  description = "The access key ID for Django S3 uploads (sensitive)"
  value       = aws_iam_access_key.django_s3_access_key.id
  sensitive   = true
}

