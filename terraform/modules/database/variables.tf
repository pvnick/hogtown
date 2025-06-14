variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy RDS in (leave empty for default VPC)"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "List of availability zones for RDS subnet group"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS (AppRunner subnets)"
  type        = list(string)
  default     = []
}

variable "lambda_subnet_ids" {
  description = "Subnet IDs where Lambda functions will be deployed (for CIDR-based access)"
  type        = list(string)
  default     = []
}

variable "database_subnet_ids" {
  description = "Subnet IDs where RDS database will be deployed"
  type        = list(string)
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "17.2"
  
  validation {
    condition = can(regex("^(11|12|13|14|15|16|17)\\.[0-9]+$", var.postgres_version))
    error_message = "PostgreSQL version must be in format 'X.Y' where X is between 11-17."
  }
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

variable "master_db_name" {
  description = "Name of the master database"
  type        = string
  default     = "postgres"
}

variable "master_username" {
  description = "Master database username"
  type        = string
  default     = "postgres"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
  
  validation {
    condition = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]-([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.backup_window))
    error_message = "Backup window must be in format 'HH:MM-HH:MM' (24-hour format)."
  }
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
  
  validation {
    condition = can(regex("^(sun|mon|tue|wed|thu|fri|sat):([0-1][0-9]|2[0-3]):[0-5][0-9]-(sun|mon|tue|wed|thu|fri|sat):([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in format 'ddd:HH:MM-ddd:HH:MM' where ddd is day of week (sun-sat)."
  }
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0
  
  validation {
    condition = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60 seconds."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (leave empty for default)"
  type        = string
  default     = ""
}