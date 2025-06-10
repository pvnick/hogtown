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