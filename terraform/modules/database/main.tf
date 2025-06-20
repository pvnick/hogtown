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
  }
}

# Get default VPC or use provided VPC
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : false
}

# Get subnets for RDS
data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  
  # Only filter by availability zones if specific zones are provided
  dynamic "filter" {
    for_each = length(var.availability_zones) > 0 ? [1] : []
    content {
      name   = "availability-zone"
      values = var.availability_zones
    }
  }
}

# Security group for RDS - restrictive access
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = data.aws_vpc.selected.id

  # Allow access from security groups
  dynamic "ingress" {
    for_each = length(var.allowed_security_groups) > 0 ? [1] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = var.allowed_security_groups
    }
  }
  
  # Allow access from CIDR blocks (use sparingly)
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

# RDS subnet group
resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = data.aws_subnets.database.ids

  tags = {
    Name    = "${var.project_name}-subnet-group"
    Project = var.project_name
  }
}

# Random password for master database user
resource "random_password" "master_password" {
  length  = 32
  special = true
}

# RDS PostgreSQL instance with production-ready configuration
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = var.kms_key_id != "" ? var.kms_key_id : null

  # Production settings
  multi_az               = var.multi_az
  publicly_accessible    = false
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  
  performance_insights_enabled = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  db_name  = var.master_db_name
  username = var.master_username
  password = random_password.master_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  
  # Parameter group for optimization
  parameter_group_name = aws_db_parameter_group.postgres.name

  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection

  tags = {
    Name        = "${var.project_name}-postgres"
    Project     = var.project_name
    Environment = "shared"
  }
}

# Parameter group for PostgreSQL optimization
resource "aws_db_parameter_group" "postgres" {
  family = "postgres${split(".", var.postgres_version)[0]}"
  name   = "${var.project_name}-postgres-params"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name    = "${var.project_name}-postgres-params"
    Project = var.project_name
  }
}

# Enhanced monitoring IAM role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.project_name}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-rds-enhanced-monitoring"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store master credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_master" {
  name        = "${var.project_name}/rds/master"
  description = "Master credentials for ${var.project_name} RDS instance"
  
  tags = {
    Name    = "${var.project_name}-rds-master"
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = random_password.master_password.result
    endpoint = aws_db_instance.postgres.endpoint
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
  })
}