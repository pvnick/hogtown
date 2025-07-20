# CI/CD Infrastructure
# Creates dedicated IAM user with minimal permissions for GitHub Actions
# to push Docker images to ECR, trigger App Runner deployments, and upload static files to S3

# IAM user for CI/CD operations (used by GitHub Actions)
resource "aws_iam_user" "ci_user" {
  name = "${local.config.project_name}-ci-user"
  path = "/"

  tags = {
    Name    = "${local.config.project_name}-ci-user"
    Project = local.config.project_name
    Purpose = "GitHub Actions CI/CD"
  }
}

# IAM policy with permissions for ECR push, App Runner deployment, and S3 static files
resource "aws_iam_policy" "ci_policy" {
  name        = "${local.config.project_name}-ci-policy"
  description = "Policy for ECR push operations, App Runner deployments, and S3 static file uploads"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.hogtown_app.arn
      },
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "AppRunnerDeployment"
        Effect = "Allow"
        Action = [
          "apprunner:ListServices",
          "apprunner:StartDeployment"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = local.config.aws_region
          }
        }
      },
      {
        Sid    = "S3StaticFilesAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.static_files.arn,
          "${aws_s3_bucket.static_files.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name    = "${local.config.project_name}-ci-policy"
    Project = local.config.project_name
  }
}

# Attach CI policy to user
resource "aws_iam_user_policy_attachment" "ci_user_policy" {
  user       = aws_iam_user.ci_user.name
  policy_arn = aws_iam_policy.ci_policy.arn
}

# Auto-generate access keys for CI user
resource "aws_iam_access_key" "ci_access_key" {
  user = aws_iam_user.ci_user.name
}

# Store CI credentials in Secrets Manager for secure access
resource "aws_secretsmanager_secret" "ci_credentials" {
  name        = "${local.config.project_name}-ci-credentials"
  description = "Auto-generated credentials for GitHub Actions CI/CD"

  tags = {
    Name    = "${local.config.project_name}-ci-credentials"
    Project = local.config.project_name
    Purpose = "GitHub Actions CI/CD"
  }
}

# Store the actual credential values
resource "aws_secretsmanager_secret_version" "ci_credentials" {
  secret_id = aws_secretsmanager_secret.ci_credentials.id
  secret_string = jsonencode({
    CI_ACCESS_KEY_ID           = aws_iam_access_key.ci_access_key.id
    CI_SECRET_ACCESS_KEY       = aws_iam_access_key.ci_access_key.secret
    ECR_REPOSITORY_URL         = aws_ecr_repository.hogtown_app.repository_url
    AWS_REGION                 = local.config.aws_region
    S3_STATIC_BUCKET           = aws_s3_bucket.static_files.bucket
  })
}