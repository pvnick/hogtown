# Hogtown Catholic

A Django web application for managing Catholic parishes, ministries, and events in Gainesville, Florida.

## Features

- **Public Directory**: Browse parishes, ministries, and events
- **Ministry Leader Registration**: Apply to become a ministry leader with admin approval
- **Ministry Portal**: Manage ministry profiles and events (ad-hoc and recurring)
- **Event Calendar**: Interactive calendar with filtering capabilities
- **Admin Dashboard**: Approve/reject registrations and manage core data

## Technology Stack

- **Backend**: Django 5.2.2
- **Database**: SQLite (development), configurable for production
- **Email**: Brevo (Sendinblue) integration via django-anymail
- **CAPTCHA**: Prosopo Procaptcha for bot protection
- **Authentication**: Custom approval-based authentication system

## Development Setup

### Prerequisites

- Python 3.11 or 3.12
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd hogtown
   ```

2. **Set up virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   pip install -r requirements-dev.txt  # For development
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run migrations**
   ```bash
   python manage.py migrate
   ```

6. **Create superuser**
   ```bash
   python manage.py createsuperuser
   ```

7. **Run development server**
   ```bash
   python manage.py runserver
   ```

## Testing

### Running Tests

```bash
# Run all tests
python manage.py test

# Run with coverage
coverage run --source='.' manage.py test
coverage report --show-missing

# Run specific test modules
python manage.py test core.test_models
python manage.py test core.test_views
python manage.py test core.test_authentication
```

### Test Structure

- `test_models.py` - Unit tests for Django models
- `test_forms.py` - Form validation and field tests
- `test_views.py` - Integration tests for views and workflows
- `test_authentication.py` - Authentication backend and login tests
- `test_admin.py` - Admin interface and bulk action tests
- `test_email.py` - Email template and notification tests

### Continuous Integration

The project uses GitHub Actions for CI/CD with the following jobs:

- **test**: Runs test suite with coverage on Python 3.11 and 3.12
- **lint**: Code quality checks with flake8, black, and isort
- **security**: Security scanning with bandit and safety

## Configuration

### Environment Variables

Create a `.env` file based on `.env.example`:

```env
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DATABASE_URL=sqlite:///db.sqlite3

# Prosopo Procaptcha
PROSOPO_SITE_KEY=your-prosopo-site-key
PROSOPO_SECRET_KEY=your-prosopo-secret-key

# Email
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
SENDINBLUE_API_KEY=your-brevo-api-key  # For production
```

### Production Deployment

For production deployment:

1. Set `DEBUG=False`
2. Configure a production database
3. Set up Brevo email service
4. Configure real Prosopo CAPTCHA keys
5. Set up proper static file serving
6. Use environment variables for sensitive settings

## Project Structure

```
hogtown/
├── core/                   # Main Django app
│   ├── models.py          # Data models
│   ├── views.py           # Views and business logic
│   ├── forms.py           # Form definitions
│   ├── admin.py           # Admin interface customization
│   ├── backends.py        # Custom authentication backend
│   ├── fields.py          # Custom form fields
│   ├── templates/         # HTML templates
│   └── test_*.py          # Test modules
├── hogtown_project/       # Django project settings
├── .github/workflows/     # CI/CD workflows
├── requirements.txt       # Production dependencies
├── requirements-dev.txt   # Development dependencies
├── .env.example          # Environment template
└── manage.py             # Django management script
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`python manage.py test`)
5. Run linting (`flake8 .`, `black .`, `isort .`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Terraform Infrastructure

The project includes production-ready Terraform configurations for deploying to AWS App Runner with multi-environment support. See [`docs/TERRAFORM_DEPLOYMENT.md`](docs/TERRAFORM_DEPLOYMENT.md) for detailed deployment instructions.

### Architecture Overview

- **Multi-Environment**: Separate staging and production environments with isolated state
- **Shared Database**: Single RDS PostgreSQL 17.2 instance with environment-specific databases
- **Security**: VPC connectors, restricted security groups, AWS Secrets Manager integration
- **Monitoring**: CloudWatch logs, Performance Insights, optional X-Ray tracing

### Directory Structure

```
terraform/
├── environments/
│   ├── prod/                 # Production App Runner service
│   │   ├── main.tf           # Production configuration
│   │   ├── variables.tf      # Production variables
│   │   └── outputs.tf        # Production outputs
│   └── staging/              # Staging App Runner service
│       ├── main.tf           # Staging configuration
│       ├── variables.tf      # Staging variables
│       └── outputs.tf        # Staging outputs
├── modules/                  # Reusable Terraform modules
│   ├── apprunner/           # App Runner with VPC connector
│   ├── database/            # RDS instance with security
│   └── database-setup/      # Environment database creation
├── shared/                  # Shared infrastructure
│   ├── main.tf              # Shared RDS and GitHub connection
│   ├── variables.tf         # Shared variables
│   └── outputs.tf           # Shared outputs
└── config/                  # Configuration templates
    ├── shared.tfbackend.example     # Shared backend config template
    ├── staging.tfbackend.example    # Staging backend config template
    ├── prod.tfbackend.example       # Production backend config template
    ├── staging.tfvars.example       # Staging variables template
    └── prod.tfvars.example          # Production variables template
```

### Prerequisites

- AWS CLI configured with appropriate permissions
- **AWS CLI profile configured** (recommended to use a named profile like `hogtown`)
- **S3 buckets and DynamoDB tables for remote state** (create these first with unique names)
- **Third-party service API keys** (Prosopo CAPTCHA, Brevo email) configured in tfvars files
- GitHub repository URL for App Runner source connection

### Backend Setup

This repository uses a decoupled backend configuration to make it public-ready. You have two options for setting up the backend:

#### Option 1: Automated Setup (Recommended)

Use the provided bootstrap script to automatically create all required AWS resources and configuration files:

**Basic Usage:**
```bash
# Quick setup with auto-generated unique prefix
./bootstrap-terraform-backend.sh

# See all available options and examples
./bootstrap-terraform-backend.sh --help
```

**Advanced Usage Examples:**
```bash
# Custom prefix and region
./bootstrap-terraform-backend.sh --prefix mycompany-hogtown-456 --region us-west-2

# Complete setup with all options
./bootstrap-terraform-backend.sh \
  --prefix myproject-123 \
  --region us-east-1 \
  --profile production \
  --github-url https://github.com/your-username/your-repo

# Using short form arguments
./bootstrap-terraform-backend.sh -p myproject-789 -r eu-west-1 -g https://github.com/user/repo
```

**Available Arguments:**
- `-p, --prefix PREFIX` - Unique prefix for AWS resources (default: auto-generated)
- `-r, --region REGION` - AWS region (default: us-east-1)
- `--profile PROFILE` - AWS CLI profile to use (default: default)
- `-g, --github-url URL` - GitHub repository URL (optional, avoids manual editing)
- `-h, --help` - Show detailed help and usage examples

**What the script does:**
- ✅ Creates S3 buckets for Terraform state with versioning and encryption
- ✅ Creates DynamoDB tables for state locking
- ✅ Generates all configuration files in the `config/` directory
- ✅ Validates AWS credentials before starting
- ✅ Provides clear next steps for deployment
- ✅ Uses unique prefixes to avoid naming conflicts

#### Option 2: Manual Setup

If you prefer to set up the infrastructure manually:

1. **Create your own S3 buckets and DynamoDB tables** using this pattern:

```bash
# Replace YOUR_UNIQUE_PREFIX with something unique to you
export BUCKET_PREFIX="YOUR_UNIQUE_PREFIX"
export AWS_REGION="us-east-1"

# Create S3 buckets for Terraform state (replace YOUR_PROFILE with your AWS profile name)
aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-shared --region ${AWS_REGION} --profile YOUR_PROFILE
aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-staging --region ${AWS_REGION} --profile YOUR_PROFILE
aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-prod --region ${AWS_REGION} --profile YOUR_PROFILE

# Enable versioning and encryption on state buckets
aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-shared --versioning-configuration Status=Enabled --profile YOUR_PROFILE
aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-staging --versioning-configuration Status=Enabled --profile YOUR_PROFILE
aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-prod --versioning-configuration Status=Enabled --profile YOUR_PROFILE

aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-shared --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --profile YOUR_PROFILE
aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-staging --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --profile YOUR_PROFILE
aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-prod --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --profile YOUR_PROFILE

# Create DynamoDB tables for state locking  
aws dynamodb create-table \
  --table-name ${BUCKET_PREFIX}-terraform-locks-shared \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION} \
  --profile YOUR_PROFILE

aws dynamodb create-table \
  --table-name ${BUCKET_PREFIX}-terraform-locks-staging \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION} \
  --profile YOUR_PROFILE

aws dynamodb create-table \
  --table-name ${BUCKET_PREFIX}-terraform-locks-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION} \
  --profile YOUR_PROFILE
```

2. **Configure backend and variables**: Copy and edit the configuration files in the `config/` directory:
   ```bash
   cd config
   cp shared.tfbackend.example shared.tfbackend
   cp staging.tfbackend.example staging.tfbackend
   cp prod.tfbackend.example prod.tfbackend
   cp shared.tfvars.example shared.tfvars
   cp staging.tfvars.example staging.tfvars
   cp prod.tfvars.example prod.tfvars
   # Edit all files with your unique bucket names, AWS profile, and GitHub repository URL
   ```

### Quick Deployment

1. **Deploy shared infrastructure** (RDS, GitHub connection):
   ```bash
   cd terraform/shared
   terraform init -backend-config-file=../../config/shared.tfbackend
   terraform apply -var-file=../../config/shared.tfvars
   ```

2. **Deploy staging environment**:
   ```bash
   cd terraform/environments/staging
   terraform init -backend-config-file=../../config/staging.tfbackend
   terraform apply -var-file=../../config/staging.tfvars
   ```

3. **Deploy production environment**:
   ```bash
   cd terraform/environments/prod
   terraform init -backend-config-file=../../config/prod.tfbackend
   terraform apply -var-file=../../config/prod.tfvars
   ```

### Key Features

- **Security**: Private database access via VPC connectors, Secrets Manager for credentials
- **Isolation**: Separate Terraform state files per environment for safety
- **Monitoring**: CloudWatch logs with configurable retention, Performance Insights
- **Scalability**: Environment-specific resource allocation and health check configuration
- **Cost Optimization**: Configurable instance classes and monitoring levels per environment

**Note**: See [`docs/TERRAFORM_DEPLOYMENT.md`](docs/TERRAFORM_DEPLOYMENT.md) for comprehensive deployment instructions, security considerations, troubleshooting guides, and cost optimization strategies.

## License

This project is licensed under the MIT License - see the LICENSE file for details.