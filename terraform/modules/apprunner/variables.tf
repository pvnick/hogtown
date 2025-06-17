variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy App Runner VPC connector in (leave empty for default VPC)"
  type        = string
  default     = ""
}

variable "enable_vpc_connector" {
  description = "Enable VPC connector for private network access"
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "Subnet IDs for the VPC connector"
  type        = list(string)
}

variable "database_security_groups" {
  description = "Security groups that App Runner should be able to access (e.g., RDS security group)"
  type        = list(string)
  default     = []
}

variable "github_repository_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to deploy from"
  type        = string
  default     = "main"
}

variable "github_connection_arn" {
  description = "GitHub connection ARN"
  type        = string
  default     = ""
}

variable "ecr_repository_url" {
  description = "ECR repository URL for container deployment (if empty, uses source code deployment)"
  type        = string
  default     = ""
}

variable "auto_deploy_enabled" {
  description = "Enable automatic deployments on code changes"
  type        = bool
  default     = true
}

variable "cpu" {
  description = "CPU units for the App Runner service"
  type        = string
  default     = "0.25 vCPU"
  
  validation {
    condition = contains([
      "0.25 vCPU",
      "0.5 vCPU", 
      "1 vCPU",
      "2 vCPU",
      "4 vCPU"
    ], var.cpu)
    error_message = "CPU must be one of: 0.25 vCPU, 0.5 vCPU, 1 vCPU, 2 vCPU, 4 vCPU."
  }
}

variable "memory" {
  description = "Memory for the App Runner service"
  type        = string
  default     = "0.5 GB"
  
  validation {
    condition = contains([
      "0.5 GB",
      "1 GB",
      "2 GB", 
      "3 GB",
      "4 GB",
      "6 GB",
      "8 GB",
      "10 GB",
      "12 GB"
    ], var.memory)
    error_message = "Memory must be one of: 0.5 GB, 1 GB, 2 GB, 3 GB, 4 GB, 6 GB, 8 GB, 10 GB, 12 GB."
  }
}

variable "secrets_manager_arns" {
  description = "List of Secrets Manager ARNs that the service needs access to"
  type        = list(string)
  default     = []
}

variable "database_secret_arn" {
  description = "ARN of the database secret in Secrets Manager"
  type        = string
  default     = ""
}

variable "app_secrets_arn" {
  description = "ARN of the application secrets in Secrets Manager"
  type        = string
  default     = ""
}

variable "app_secrets_name" {
  description = "Name of the application secrets in Secrets Manager"
  type        = string
  default     = ""
}


variable "additional_env_vars" {
  description = "Additional environment variables to set for the App Runner service"
  type        = map(string)
  default     = {}
}

# Health check configuration
variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks"
  type        = number
  default     = 1
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "health_check_protocol" {
  description = "Health check protocol"
  type        = string
  default     = "HTTP"
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks"
  type        = number
  default     = 5
}

# Observability configuration
variable "observability_enabled" {
  description = "Enable observability (X-Ray tracing)"
  type        = bool
  default     = false
}

variable "observability_configuration_arn" {
  description = "ARN of observability configuration"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}