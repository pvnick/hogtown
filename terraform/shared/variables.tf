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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for RDS subnet group"
  type        = list(string)
  default     = []
}

variable "allowed_security_groups" {
  description = "Security groups allowed to access RDS"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS (use sparingly, prefer security groups)"
  type        = list(string)
  default     = []
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "17.2"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage for the database (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for the database (GB)"
  type        = number
  default     = 1000
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability (recommended for production)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying (set to false for production)"
  type        = bool
  default     = false
}

# Application secrets variables
variable "prosopo_site_key" {
  description = "Prosopo site key for CAPTCHA"
  type        = string
  default     = ""
  sensitive   = true
}

variable "prosopo_secret_key" {
  description = "Prosopo secret key for CAPTCHA"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sendinblue_api_key" {
  description = "Sendinblue API key for email"
  type        = string
  default     = ""
  sensitive   = true
}

variable "default_from_email" {
  description = "Default from email address"
  type        = string
  default     = "noreply@hogtowncatholic.org"
}

variable "allowed_hosts" {
  description = "Comma-separated list of allowed hosts for Django"
  type        = string
  default     = ""
}

# GitHub repository configuration
variable "github_repository_url" {
  description = "GitHub repository URL for App Runner source connection"
  type        = string
  default     = ""
}