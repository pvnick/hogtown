# S3 Bucket for static files
resource "aws_s3_bucket" "static_files" {
  bucket = "${local.config.project_name}-static-files"

  tags = {
    Name    = "${local.config.project_name}-static-files"
    Project = local.config.project_name
    Purpose = "Static file storage for Django application"
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "static_files" {
  bucket = aws_s3_bucket.static_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block (keep private, CloudFront will access)
resource "aws_s3_bucket_public_access_block" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket CORS configuration
resource "aws_s3_bucket_cors_configuration" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = [
      "https://${local.config.domain_name}",
      "https://staging.${local.config.domain_name}"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "static_files" {
  comment = "OAI for ${local.config.project_name} static files"
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.static_files.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_files.arn}/*"
      }
    ]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "static_files" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for ${local.config.project_name} static files"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Use only North America and Europe edge locations

  aliases = ["static.${local.config.domain_name}"]

  origin {
    domain_name = aws_s3_bucket.static_files.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_files.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static_files.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Method", "Access-Control-Request-Headers"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # 1 day
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # Cache behavior for CSS and JS files
  ordered_cache_behavior {
    path_pattern     = "*.css"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 604800   # 7 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.js"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 604800   # 7 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # Cache behavior for images
  ordered_cache_behavior {
    path_pattern     = "*.jpg"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 2592000  # 30 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.jpeg"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 2592000  # 30 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.png"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 2592000  # 30 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.gif"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 2592000  # 30 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.webp"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_files.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 2592000  # 30 days
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.main.arn
    ssl_support_method  = "sni-only"
  }

  tags = {
    Name    = "${local.config.project_name}-static-cdn"
    Project = local.config.project_name
  }
}

# Route 53 record for CloudFront distribution
resource "aws_route53_record" "static_cdn" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "static.${local.config.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_files.domain_name
    zone_id                = aws_cloudfront_distribution.static_files.hosted_zone_id
    evaluate_target_health = false
  }
}

# IAM user for Django static file uploads
resource "aws_iam_user" "django_s3_user" {
  name = "${local.config.project_name}-django-s3-user"
  path = "/"

  tags = {
    Name    = "${local.config.project_name}-django-s3-user"
    Project = local.config.project_name
    Purpose = "Django S3 static file uploads"
  }
}

# IAM policy for S3 access
resource "aws_iam_policy" "django_s3_policy" {
  name        = "${local.config.project_name}-django-s3-policy"
  description = "Policy for Django to upload static files to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
    Name    = "${local.config.project_name}-django-s3-policy"
    Project = local.config.project_name
  }
}

# Attach S3 policy to user
resource "aws_iam_user_policy_attachment" "django_s3_user_policy" {
  user       = aws_iam_user.django_s3_user.name
  policy_arn = aws_iam_policy.django_s3_policy.arn
}

# Auto-generate access keys for S3 user
resource "aws_iam_access_key" "django_s3_access_key" {
  user = aws_iam_user.django_s3_user.name
}

# Update Secrets Manager with S3 credentials
resource "aws_secretsmanager_secret_version" "django_app_config_with_s3" {
  secret_id = aws_secretsmanager_secret.django_app_config.id
  secret_string = jsonencode({
    # Django application secrets
    SECRET_KEY         = random_password.django_secret_key.result
    PROSOPO_SITE_KEY   = local.config.prosopo_site_key
    PROSOPO_SECRET_KEY = local.config.prosopo_secret_key

    # Email service credentials (auto-generated)
    EMAIL_SERVICE_ACCESS_KEY_ID     = aws_iam_access_key.email_service_access_key.id
    EMAIL_SERVICE_SECRET_ACCESS_KEY = aws_iam_access_key.email_service_access_key.secret
    AWS_REGION                      = local.config.aws_region
    DEFAULT_FROM_EMAIL              = local.config.default_from_email
    ALLOWED_HOSTS                   = local.config.allowed_hosts

    # Database connection details
    DB_HOST = module.database.database_endpoint
    DB_PORT = tostring(module.database.database_port)
    DB_NAME = module.database.database_name

    # S3 static files configuration
    USE_S3                  = "True"
    AWS_STORAGE_BUCKET_NAME = aws_s3_bucket.static_files.bucket
    AWS_S3_ACCESS_KEY_ID    = aws_iam_access_key.django_s3_access_key.id
    AWS_S3_SECRET_ACCESS_KEY = aws_iam_access_key.django_s3_access_key.secret
    AWS_S3_CUSTOM_DOMAIN    = aws_cloudfront_distribution.static_files.domain_name
    AWS_CLOUDFRONT_DOMAIN   = "static.${local.config.domain_name}"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}