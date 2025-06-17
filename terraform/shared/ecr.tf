resource "aws_ecr_repository" "hogtown_app" {
  name                 = "hogtown-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "hogtown-app"
    Environment = "shared"
  }
}

resource "aws_ecr_lifecycle_policy" "hogtown_app" {
  repository = aws_ecr_repository.hogtown_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}