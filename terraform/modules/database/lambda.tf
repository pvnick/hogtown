
# Security group for Lambda to access RDS
resource "aws_security_group" "lambda_db_setup" {
  name        = "${var.project_name}-lambda-db-setup-sg"
  description = "Security group for Lambda database setup function"
  vpc_id      = data.aws_vpc.selected.id

  # PostgreSQL access to RDS - restricted to database subnets only
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [for subnet in data.aws_subnet.database_subnets : subnet.cidr_block]
    description = "Allow Lambda to access RDS on port 5432 in database subnets only"
  }

  # HTTPS access to VPC endpoints (Secrets Manager, CloudWatch Logs, KMS)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  tags = {
    Name    = "${var.project_name}-lambda-db-setup-sg"
    Project = var.project_name
  }
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_db_setup" {
  name = "${var.project_name}-lambda-db-setup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-lambda-db-setup-iam-role"
    Project = var.project_name
  }
}

# IAM policy for Lambda to access Secrets Manager and VPC
resource "aws_iam_role_policy" "lambda_db_setup" {
  name = "${var.project_name}-lambda-db-setup-policy"
  role = aws_iam_role.lambda_db_setup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:TagResource",
          "secretsmanager:RestoreSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_master.arn,
          "arn:aws:secretsmanager:*:*:secret:${var.project_name}/database/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          # Allow access to custom RDS KMS key if specified
          var.kms_key_id != ""
            ? var.kms_key_id
            # Otherwise allow access to default AWS managed RDS KMS key
            : "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/rds",
          # Allow access to AWS managed Lambda KMS key
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/lambda",
          # Allow access to Secrets Manager KMS key  
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/secretsmanager"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for Lambda VPC access
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_db_setup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda layer with psycopg2 for PostgreSQL connectivity
resource "aws_lambda_layer_version" "psycopg2" {
  filename            = "${path.module}/psycopg2-layer.zip"
  layer_name          = "${var.project_name}-psycopg2-layer"
  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  description         = "psycopg2 library for PostgreSQL connectivity"

  lifecycle {
    ignore_changes = [filename]
  }
}

# Lambda function for database setup
resource "aws_lambda_function" "db_setup" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-db-setup"
  role            = aws_iam_role.lambda_db_setup.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  layers = [aws_lambda_layer_version.psycopg2.arn]

  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = [aws_security_group.lambda_db_setup.id]
  }

  environment {
    variables = {
      PROJECT_NAME = var.project_name
    }
  }

  # Explicitly disable KMS encryption for environment variables
  kms_key_arn = ""

  tags = {
    Name    = "${var.project_name}-db-setup"
    Project = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_iam_role_policy.lambda_db_setup,
    aws_lambda_layer_version.psycopg2
  ]
}
