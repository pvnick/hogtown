# ECR CI/CD Infrastructure
# Creates dedicated IAM user with minimal permissions for GitHub Actions
# to push Docker images to ECR and trigger App Runner deployments

# IAM user for ECR push operations (used by GitHub Actions)
resource "aws_iam_user" "ecr_push_user" {
  name = "${local.config.project_name}-ecr-push-user"
  path = "/"

  tags = {
    Name    = "${local.config.project_name}-ecr-push-user"
    Project = local.config.project_name
    Purpose = "GitHub Actions ECR Push"
  }
}

# IAM policy with minimal permissions for ECR push and App Runner deployment
resource "aws_iam_policy" "ecr_push_policy" {
  name        = "${local.config.project_name}-ecr-push-policy"
  description = "Minimal policy for ECR push operations and App Runner deployments"

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
      }
    ]
  })

  tags = {
    Name    = "${local.config.project_name}-ecr-push-policy"
    Project = local.config.project_name
  }
}

# Attach ECR push policy to user
resource "aws_iam_user_policy_attachment" "ecr_push_user_policy" {
  user       = aws_iam_user.ecr_push_user.name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}

# Auto-generate access keys for ECR push user
resource "aws_iam_access_key" "ecr_push_access_key" {
  user = aws_iam_user.ecr_push_user.name
}

# Store ECR push credentials in Secrets Manager for secure access
resource "aws_secretsmanager_secret" "ecr_push_credentials" {
  name        = "${local.config.project_name}-ecr-push-credentials"
  description = "Auto-generated credentials for GitHub Actions ECR push"

  tags = {
    Name    = "${local.config.project_name}-ecr-push-credentials"
    Project = local.config.project_name
    Purpose = "GitHub Actions CI/CD"
  }
}

# Store the actual credential values
resource "aws_secretsmanager_secret_version" "ecr_push_credentials" {
  secret_id = aws_secretsmanager_secret.ecr_push_credentials.id
  secret_string = jsonencode({
    ECR_PUSH_ACCESS_KEY_ID     = aws_iam_access_key.ecr_push_access_key.id
    ECR_PUSH_SECRET_ACCESS_KEY = aws_iam_access_key.ecr_push_access_key.secret
    ECR_REPOSITORY_URL         = aws_ecr_repository.hogtown_app.repository_url
    AWS_REGION                 = local.config.aws_region
  })
}