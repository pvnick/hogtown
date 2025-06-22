output "app_runner_service_url" {
  description = "The URL of the App Runner service"
  value       = "https://${aws_apprunner_service.main.service_url}"
}

output "app_runner_service_arn" {
  description = "The ARN of the App Runner service"
  value       = aws_apprunner_service.main.arn
}

output "app_runner_service_id" {
  description = "The ID of the App Runner service"
  value       = aws_apprunner_service.main.service_id
}

output "app_runner_service_status" {
  description = "The status of the App Runner service"
  value       = aws_apprunner_service.main.status
}

output "vpc_connector_arn" {
  description = "The ARN of the VPC connector (if enabled)"
  value       = var.enable_vpc_connector ? aws_apprunner_vpc_connector.main[0].arn : null
}

output "security_group_id" {
  description = "The security group ID for the VPC connector (if enabled)"
  value       = var.enable_vpc_connector ? aws_security_group.apprunner_vpc_connector[0].id : null
}

output "log_group_name" {
  description = "The CloudWatch log group name"
  value       = aws_cloudwatch_log_group.apprunner.name
}

# Custom domain outputs
output "custom_domain_name" {
  description = "The custom domain name (if configured)"
  value       = var.custom_domain_name != "" ? var.custom_domain_name : null
}

output "custom_domain_url" {
  description = "The custom domain URL (if configured)"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}" : null
}

output "custom_domain_association_status" {
  description = "The status of the custom domain association (if configured)"
  value       = var.custom_domain_name != "" ? aws_apprunner_custom_domain_association.main[0].status : null
}

output "dns_target" {
  description = "The DNS target for CNAME record (if custom domain is configured)"
  value       = var.custom_domain_name != "" ? aws_apprunner_custom_domain_association.main[0].dns_target : null
}