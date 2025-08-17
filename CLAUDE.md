# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Django web application project called "hogtown_project" with a core app.

## Development Commands

### Environment Setup
- Activate virtual environment: `source venv/bin/activate`
- Install dependencies: `pip install -r requirements.txt`

### Django Commands
- Run development server: `python manage.py runserver`
- Create migrations: `python manage.py makemigrations`
- Apply migrations: `python manage.py migrate`
- Create superuser: `python manage.py createsuperuser`
- Run tests: `python manage.py test`
- Collect static files: `python manage.py collectstatic`

### Project Structure
- `hogtown_project/`: Main Django project directory containing settings and configuration
- `core/`: Primary Django app for core functionality
- `venv/`: Python virtual environment (excluded from git)
- `requirements.txt`: Python package dependencies

## Email Configuration

### Development
- Default: Console backend (emails printed to console)
- To test with AWS SES locally, update `.env` file:
  ```
  EMAIL_BACKEND=anymail.backends.amazon_ses.EmailBackend
  EMAIL_SERVICE_ACCESS_KEY_ID=your-key-here
  EMAIL_SERVICE_SECRET_ACCESS_KEY=your-secret-here
  EMAIL_SERVICE_AWS_REGION=us-east-1
  ```

### Production
- Uses AWS SES via django-anymail
- Credentials automatically generated and managed by Terraform
- IAM user with minimal SES permissions created automatically
- Email templates: `core/templates/core/emails/`

### Email Types
- Admin notifications (new user registrations)
- User approval notifications
- User rejection notifications
- All emails support retry mechanism through Django admin

## Development Notes

- Always activate the virtual environment before running Django commands
- The project uses Django 5.2.2
- Main app is called "core" - add new features here or create additional apps as needed
- Email service uses AWS SES (migrated from Brevo/Sendinblue)

## Pre-Commit Checklist

### Code Quality - ALWAYS Run Before Git Push
**CRITICAL**: Always run black formatting on all Python files before pushing to git

```bash
# Activate virtual environment
source venv/bin/activate

# Format all Python files with black
black .

# Check import sorting
isort --check-only --diff .
# Fix imports if needed
isort .

# Run flake8 linting
flake8 .

# Run Django checks
python manage.py check
python manage.py check --deploy
```

### Why This Matters
- The CI pipeline includes black formatting checks that will fail if code isn't properly formatted
- Running black locally prevents CI failures and maintains code consistency
- The project uses specific flake8 configuration in `.flake8` file
- Django security checks help catch configuration issues

### Django-Specific Commands
```bash
# Test the application
python manage.py test

# Check for missing migrations
python manage.py makemigrations --dry-run --check

# Collect static files (if needed)
python manage.py collectstatic --noinput
```

### Git Workflow
```bash
# After running black and other checks
git add .
git commit -m "Your commit message"
git push origin develop  # or main
```

### Code Style Configuration
- Black: Default configuration (line length 88)
- isort: Compatible with black profile, configured in `setup.cfg`
  - Line length: 127 (matches flake8)
  - Sections: FUTURE, STDLIB, THIRDPARTY, DJANGO, FIRSTPARTY, LOCALFOLDER
  - Known Django: django
  - Known first party: core, hogtown_project
- flake8: Custom configuration in `setup.cfg` with complexity exclusions
- Django: Follow Django coding standards

### Common Issues to Avoid
- Forgetting to run black before commit (causes CI failures)
- Not activating virtual environment before commands
- Pushing without running Django checks
- Missing import sorting with isort (CI runs `isort --check-only --diff .`)
- Import order must follow: stdlib → third-party → Django → first-party

## Custom Domain Configuration

### Domain Setup
- **Production**: `hogtowncatholic.com` → Production App Runner service
- **Staging**: `staging.hogtowncatholic.com` → Staging App Runner service
- Domain registered externally but DNS managed by AWS Route 53
- SSL certificate from ACM uses DNS validation
- Wildcard certificate covers both main domain and subdomains (*.hogtowncatholic.com)
- App Runner creates separate certificates for custom domains with automatic validation

### DNS Configuration Steps
1. **Deploy Shared Infrastructure**: Creates Route 53 hosted zone and ACM certificate
2. **Get Route 53 Nameservers**: Run `terraform output hosted_zone_name_servers` in shared directory
3. **Update Domain Registrar**: Point domain to Route 53 nameservers from step 2
4. **Deploy Environment Infrastructure**: Creates App Runner services with custom domains
5. **Automatic Certificate Validation**: App Runner certificates validated via DNS automatically

### DNS Records Created Automatically
- ACM certificate validation records (for shared SSL certificate)
- App Runner certificate validation records (for custom domain certificates)
- CNAME records pointing custom domains to App Runner DNS targets

### Email Configuration
- Default sender: `noreply@hogtowncatholic.com`
- SES domain identity configured for hogtowncatholic.com
- ALLOWED_HOSTS includes both production and staging domains

## Infrastructure Architecture

### Shared Resources (`terraform/shared/`)
- Route 53 hosted zone and SSL certificate
- VPC with private subnets for RDS, App Runner, and Lambda
- ECR repository for Docker images
- RDS PostgreSQL database with automated setup
- Secrets Manager for application configuration
- IAM users and policies for email service and ECR access
- S3 bucket for static files with versioning enabled
- CloudFront CDN distribution for static file delivery
- IAM user for Django S3 uploads with minimal permissions

### Environment-Specific Resources
- **Staging** (`terraform/environments/staging/`): App Runner service with staging subdomain
- **Production** (`terraform/environments/prod/`): App Runner service with main domain
- Environment-specific databases and configuration

### Deployment Flow
1. **Shared Infrastructure**: Apply first to create base resources
   ```bash
   cd terraform/shared
   terraform init -backend-config=../config/shared.tfbackend
   terraform plan
   terraform apply
   ```

2. **Domain Delegation**: Update registrar to use Route 53 name servers
   ```bash
   terraform output hosted_zone_name_servers
   # Copy nameservers to domain registrar DNS settings
   ```

3. **Environment Infrastructure**: Apply staging and production environments
   ```bash
   # Staging
   cd ../environments/staging
   terraform init -backend-config=../../config/staging.tfbackend
   terraform plan
   terraform apply
   
   # Production (when ready)
   cd ../prod
   terraform init -backend-config=../../config/prod.tfbackend
   terraform plan
   terraform apply
   ```

4. **CI/CD**: GitHub Actions builds and pushes to ECR, App Runner auto-deploys

### Troubleshooting Domain Setup
- **Certificate validation pending**: Check that nameservers were updated at registrar
- **Terraform state locks**: Use `terraform force-unlock <lock-id>` if needed
- **Custom domain not working**: Allow 5-10 minutes for App Runner certificate validation
- **SSL errors**: App Runner creates separate certificates that take time to validate

## CI/CD Pipeline

### Comprehensive Workflow
- **Single optimized pipeline**: `ci.yml` handles all validation and deployment
- **Smart conditional logic**: Terraform validation only runs when terraform files change
- **Dependency-based deployment**: Docker images only build if all tests pass
- **Efficient resource usage**: Eliminates duplicate jobs across workflows

### Jobs Included
1. **Django Tests**: Unit tests, migrations, coverage, security checks
2. **Code Quality**: flake8 linting, black formatting, isort import sorting
3. **Security Scanning**: bandit code analysis, safety dependency checks
4. **Terraform Validation**: Format, init, and validate (when terraform changes detected)
5. **Terraform Security**: Checkov and TFSec scanning (when terraform changes detected)
6. **Docker Build & Deploy**: ECR push only on successful validation (push events only, not PRs)

### Workflow Triggers
- **Push to main/develop**: Full pipeline including Docker build
- **Pull Request**: Validation only (no Docker build)
- **Terraform changes**: Additional terraform validation jobs

## Terraform Guidelines
- Whenever doing a terraform init make sure to look for the tfbackend files in terraform/config
- Whenever you write terraform code, use context7
- Apply shared infrastructure first, then environment-specific resources
- Domain configuration is centralized in shared infrastructure
- Use AWS profile `hogtown` for all AWS CLI commands
- Terraform backend files are located in `terraform/config/`

### Key Configuration Changes Made
1. **Route 53 Integration**: Added Route 53 hosted zone for DNS management with external domain registration
2. **SSL Certificate**: Changed from EMAIL to DNS validation for automatic validation
3. **App Runner Custom Domains**: Added automatic certificate validation record creation in DNS
4. **Dual Certificate Setup**: ACM certificate for shared resources + App Runner certificates for custom domains
5. **Static Files CDN**: Added S3 bucket and CloudFront distribution for static file serving
6. **Django Storages**: Configured django-storages for S3 static file uploads
7. **CloudFront Domain**: static.hogtowncatholic.com serves static assets globally

### Current Status
- **Shared Infrastructure**: ✅ Deployed with Route 53 hosted zone and SSL certificate
- **Staging Environment**: ✅ Deployed with custom domain `staging.hogtowncatholic.com`
- **Production Environment**: ⏸️ Ready to deploy (skipped per user request)
- **Domain Nameservers**: ✅ Updated at registrar to point to Route 53
- **SSL Security**: ✅ Mixed content warnings fixed with CSP headers

## SSL/HTTPS Security & Mixed Content Resolution

### Problem & Solution
**Issue**: Browser mixed content warnings despite valid SSL certificates
**Root Cause**: Missing Content Security Policy (CSP) headers
**Solution**: Added django-csp package with strict HTTPS-only policies

### Security Configuration Added
```python
# requirements.txt
django-csp==3.8

# settings.py
INSTALLED_APPS = [..., "csp", ...]
MIDDLEWARE = [..., "csp.middleware.CSPMiddleware", ...]

# Content Security Policy to prevent mixed content
CSP_DEFAULT_SRC = ["'self'"]
CSP_SCRIPT_SRC = ["'self'", "https://cdn.jsdelivr.net", "https://js.prosopo.io", "'unsafe-inline'"]
CSP_STYLE_SRC = ["'self'", "https://cdn.jsdelivr.net", "'unsafe-inline'"]
CSP_IMG_SRC = ["'self'", "data:", "https:"]
CSP_FONT_SRC = ["'self'", "https://cdn.jsdelivr.net"]
CSP_CONNECT_SRC = ["'self'", "https:"]

# HTTPS Transport Security (production only)
if not DEBUG:
    SECURE_HSTS_SECONDS = 31536000  # 1 year
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

# Additional security headers
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = "DENY"
```

### Key Learning
Modern browsers require explicit CSP headers to prevent mixed content warnings, not just valid SSL certificates. The django-csp package provides comprehensive protection against HTTP resource loading on HTTPS sites.

## Infrastructure Patterns & Best Practices

### Terraform Configuration Patterns
- **Backend Files**: Always use `.tfbackend` files in `terraform/config/`
- **AWS Profile**: Use `hogtown` profile for all AWS CLI commands
- **State Locks**: Use `terraform force-unlock <lock-id>` when needed
- **Deployment Order**: Shared infrastructure → environment-specific resources

### Debugging & Troubleshooting
#### SSL Issues
1. **Check CSP Headers**: Use browser dev tools to verify Content-Security-Policy headers
2. **App Runner Certificates**: Allow 5-10 minutes for validation after DNS changes
3. **Mixed Content**: Look for CSP violations in browser console, not just certificate validity

#### Terraform Issues
- **State Locks**: Check for `.terraform.lock.hcl` and use force-unlock if needed
- **Backend Config**: Always specify `-backend-config=../config/name.tfbackend`
- **Validation Sequence**: fmt → init → validate → plan → apply

#### Django Production Debugging
- **CloudWatch Logs**: `/aws/apprunner/hogtown-staging/*/application`
- **Comprehensive Logging**: Configured in settings.py with detailed formatters
- **Health Check**: Separate endpoint without database dependencies

## Static Files CDN Configuration

### Production Static Files
- **S3 Bucket**: `hogtown-static-files` (private, versioned)
- **CloudFront CDN**: `static.hogtowncatholic.com`
- **Django Storage**: `django-storages[s3]` with boto3
- **Cache Headers**: 1 day for JS/CSS, 30 days for images
- **CORS**: Configured for production and staging domains

### Development Static Files
- **Local Storage**: `staticfiles/` directory
- **Served by Django**: `python manage.py runserver`
- **Collection**: `python manage.py collectstatic`

### Static File Upload Process
1. Development: Files served locally from `core/static/`
2. Production: 
   - `collectstatic` uploads to S3 during deployment
   - CloudFront serves files globally with caching
   - Automatic invalidation not configured (manual if needed)

### Environment Variables
- `USE_S3`: Set to "True" in production environments
- `AWS_STORAGE_BUCKET_NAME`: S3 bucket name
- `AWS_CLOUDFRONT_DOMAIN`: Custom CloudFront domain
- All credentials managed via AWS Secrets Manager
