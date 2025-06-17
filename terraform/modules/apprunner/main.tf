terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get current AWS region
data "aws_region" "current" {}

# Get VPC information for App Runner VPC connector
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : false
}

locals {
  subnet_ids = var.subnet_ids
}

# Security group for App Runner VPC connector
resource "aws_security_group" "apprunner_vpc_connector" {
  count       = var.enable_vpc_connector ? 1 : 0
  name        = "${var.app_name}-apprunner-vpc-sg"
  description = "Security group for App Runner VPC connector"
  vpc_id      = data.aws_vpc.selected.id

  # Outbound access to RDS
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.database_security_groups
  }

  # Outbound HTTPS for external APIs
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP for external APIs (if needed)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-apprunner-vpc-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# VPC connector for App Runner to access RDS in VPC
resource "aws_apprunner_vpc_connector" "main" {
  count              = var.enable_vpc_connector ? 1 : 0
  vpc_connector_name = "${var.app_name}-vpc-connector"
  subnets            = local.subnet_ids
  security_groups    = [aws_security_group.apprunner_vpc_connector[0].id]

  tags = {
    Name        = "${var.app_name}-vpc-connector"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for App Runner service with minimal permissions
resource "aws_iam_role" "apprunner_service_role" {
  name = "${var.app_name}-apprunner-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-service-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Collect all secret ARNs that need access
locals {
  all_secret_arns = compact(concat(
    var.secrets_manager_arns,
    var.app_secrets_arn != "" ? [var.app_secrets_arn] : [],
    var.database_secret_arn != "" ? [var.database_secret_arn] : []
  ))
}

# Policy for accessing Secrets Manager
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.app_name}-secrets-access"
  description = "Allow App Runner to access required secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = length(local.all_secret_arns) > 0 ? [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.all_secret_arns
      }
    ] : []
  })

  tags = {
    Name        = "${var.app_name}-secrets-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy for accessing ECR when using container deployment
resource "aws_iam_policy" "ecr_access" {
  count = var.ecr_repository_url != "" ? 1 : 0
  name  = "${var.app_name}-ecr-access"
  description = "Allow App Runner to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-ecr-policy"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.apprunner_service_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  count      = var.ecr_repository_url != "" ? 1 : 0
  role       = aws_iam_role.apprunner_service_role.name
  policy_arn = aws_iam_policy.ecr_access[0].arn
}

# IAM role for App Runner build (accessing ECR, etc.)
resource "aws_iam_role" "apprunner_build_role" {
  name = "${var.app_name}-apprunner-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-build-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "apprunner_build_role_policy" {
  role       = aws_iam_role.apprunner_build_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# App Runner service with improved configuration
resource "aws_apprunner_service" "main" {
  service_name = var.app_name

  source_configuration {
    auto_deployments_enabled = var.auto_deploy_enabled
    
    # Use image repository when ECR repository URL is provided
    dynamic "image_repository" {
      for_each = var.ecr_repository_url != "" ? [1] : []
      content {
        image_identifier      = "${var.ecr_repository_url}:latest"
        image_repository_type = "ECR"
        
        image_configuration {
          runtime_environment_variables = merge({
            DJANGO_SETTINGS_MODULE = "hogtown_project.settings"
            DEBUG                  = "False"
            EMAIL_BACKEND         = "anymail.backends.amazon_ses.EmailBackend"
            PORT                   = "8000"
          }, var.additional_env_vars)
          
          runtime_environment_secrets = merge(
            # Database connection string from database secret
            var.database_secret_arn != "" ? {
              DATABASE_URL = "${var.database_secret_arn}:database_url::"
              DB_USERNAME  = "${var.database_secret_arn}:username::"
              DB_PASSWORD  = "${var.database_secret_arn}:password::"
              DB_HOST      = "${var.database_secret_arn}:endpoint::"
              DB_PORT      = "${var.database_secret_arn}:port::"
              DB_NAME      = "${var.database_secret_arn}:dbname::"
            } : {},
            # Application secrets from central secret store
            var.app_secrets_arn != "" ? {
              SECRET_KEY            = "${var.app_secrets_arn}:SECRET_KEY::"
              PROSOPO_SITE_KEY     = "${var.app_secrets_arn}:PROSOPO_SITE_KEY::"
              PROSOPO_SECRET_KEY   = "${var.app_secrets_arn}:PROSOPO_SECRET_KEY::"
              EMAIL_SERVICE_ACCESS_KEY_ID    = "${var.app_secrets_arn}:EMAIL_SERVICE_ACCESS_KEY_ID::"
              EMAIL_SERVICE_SECRET_ACCESS_KEY = "${var.app_secrets_arn}:EMAIL_SERVICE_SECRET_ACCESS_KEY::"
              EMAIL_SERVICE_AWS_REGION       = "${var.app_secrets_arn}:AWS_REGION::"
              DEFAULT_FROM_EMAIL   = "${var.app_secrets_arn}:DEFAULT_FROM_EMAIL::"
              ALLOWED_HOSTS        = "${var.app_secrets_arn}:ALLOWED_HOSTS::"
            } : {}
          )
        }
      }
    }
    
    # Use code repository when ECR repository URL is not provided (fallback)
    dynamic "code_repository" {
      for_each = var.ecr_repository_url == "" ? [1] : []
      content {
        repository_url = var.github_repository_url
        
        authentication_configuration {
          connection_arn = var.github_connection_arn
        }
        
        code_configuration {
          configuration_source = "API"
          
          code_configuration_values {
            runtime = "PYTHON_311"
            build_command = "sh build.sh"
            start_command = "sh start.sh"
            
            runtime_environment_variables = merge({
              DJANGO_SETTINGS_MODULE = "hogtown_project.settings"
              DEBUG                  = "False"
              EMAIL_BACKEND         = "anymail.backends.amazon_ses.EmailBackend"
              PORT                   = "8000"
            }, var.additional_env_vars)
            
            runtime_environment_secrets = merge(
              var.database_secret_arn != "" ? {
                DATABASE_URL = "${var.database_secret_arn}:database_url::"
                DB_USERNAME  = "${var.database_secret_arn}:username::"
                DB_PASSWORD  = "${var.database_secret_arn}:password::"
                DB_HOST      = "${var.database_secret_arn}:endpoint::"
                DB_PORT      = "${var.database_secret_arn}:port::"
                DB_NAME      = "${var.database_secret_arn}:dbname::"
              } : {},
              var.app_secrets_arn != "" ? {
                SECRET_KEY            = "${var.app_secrets_arn}:SECRET_KEY::"
                PROSOPO_SITE_KEY     = "${var.app_secrets_arn}:PROSOPO_SITE_KEY::"
                PROSOPO_SECRET_KEY   = "${var.app_secrets_arn}:PROSOPO_SECRET_KEY::"
                EMAIL_SERVICE_ACCESS_KEY_ID    = "${var.app_secrets_arn}:EMAIL_SERVICE_ACCESS_KEY_ID::"
                EMAIL_SERVICE_SECRET_ACCESS_KEY = "${var.app_secrets_arn}:EMAIL_SERVICE_SECRET_ACCESS_KEY::"
                EMAIL_SERVICE_AWS_REGION       = "${var.app_secrets_arn}:AWS_REGION::"
                DEFAULT_FROM_EMAIL   = "${var.app_secrets_arn}:DEFAULT_FROM_EMAIL::"
                ALLOWED_HOSTS        = "${var.app_secrets_arn}:ALLOWED_HOSTS::"
              } : {}
            )
          }
        }
        
        source_code_version {
          type  = "BRANCH"
          value = var.github_branch
        }
      }
    }
  }

  instance_configuration {
    cpu               = var.cpu
    memory            = var.memory
    instance_role_arn = aws_iam_role.apprunner_service_role.arn
  }

  # VPC configuration for database access
  dynamic "network_configuration" {
    for_each = var.enable_vpc_connector ? [1] : []
    content {
      egress_configuration {
        egress_type       = "VPC"
        vpc_connector_arn = aws_apprunner_vpc_connector.main[0].arn
      }
    }
  }

  health_check_configuration {
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = var.health_check_protocol
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  # Observability configuration
  observability_configuration {
    observability_enabled   = var.observability_enabled
    observability_configuration_arn = var.observability_configuration_arn
  }

  tags = {
    Name        = var.app_name
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for App Runner logs
resource "aws_cloudwatch_log_group" "apprunner" {
  name              = "/aws/apprunner/${var.app_name}/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.app_name}-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}