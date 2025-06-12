variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "hogtown"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = ""
}

# Backend configuration variables for shared state access
variable "shared_state_bucket" {
  description = "S3 bucket name containing shared Terraform state"
  type        = string
}

variable "shared_state_key" {
  description = "S3 key for shared Terraform state file"
  type        = string
  default     = "hogtown/shared.tfstate"
}

variable "shared_state_region" {
  description = "AWS region for shared state bucket"
  type        = string
  default     = "us-east-1"
}

# GitHub repository URL comes from shared infrastructure
# Branch configuration for this environment

variable "prod_branch" {
  description = "GitHub branch for production deployment"
  type        = string
  default     = "main"
}

variable "auto_deploy_enabled" {
  description = "Enable automatic deployments on code changes (recommended: false for production)"
  type        = bool
  default     = false
}

variable "prod_cpu" {
  description = "CPU units for production App Runner service"
  type        = string
  default     = "0.5 vCPU"
}

variable "prod_memory" {
  description = "Memory for production App Runner service"
  type        = string
  default     = "1 GB"
}

variable "observability_enabled" {
  description = "Enable observability (X-Ray tracing)"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks"
  type        = number
  default     = 5
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}