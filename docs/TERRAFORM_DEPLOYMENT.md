# Production-Ready Multi-Environment Terraform Deployment

This setup deploys the Django application to AWS App Runner with separate staging and production environments using a robust, secure architecture.

## Architecture Overview

- **Shared Infrastructure**: Single RDS PostgreSQL 17.2 instance with separate databases per environment
- **Security**: VPC connectors, restricted security groups, AWS Secrets Manager for credentials
- **Monitoring**: CloudWatch logs, optional X-Ray tracing, Performance Insights support
- **Isolation**: Separate Terraform state per environment for safety and team collaboration

## Directory Structure

```
terraform/
├── shared/                    # Shared RDS instance and GitHub connection
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── environments/
│   ├── staging/              # Staging App Runner service
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/                 # Production App Runner service
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── modules/
│   ├── database/             # RDS instance with security
│   ├── database-setup/       # Environment database creation
│   └── apprunner/           # App Runner with VPC connector
└── config/                   # Configuration templates
    ├── shared.tfbackend.example     # Shared backend config template
    ├── staging.tfbackend.example    # Staging backend config template
    ├── prod.tfbackend.example       # Production backend config template
    ├── shared.tfvars.example        # Shared variables template
    ├── staging.tfvars.example       # Staging variables template
    └── prod.tfvars.example          # Production variables template
```

## Key Improvements

### Security Enhancements
- **Restricted RDS Access**: Security groups allow only App Runner services to access database
- **VPC Connector**: App Runner connects to RDS via private networking
- **Secrets Manager**: Database credentials stored securely, rotatable
- **Least Privilege IAM**: App Runner roles have minimal required permissions

### Production Features
- **Multi-AZ Support**: Optional for RDS high availability
- **Enhanced Monitoring**: CloudWatch logs, Performance Insights, X-Ray tracing
- **Backup & Recovery**: Configurable backup retention and maintenance windows
- **Encryption**: RDS encryption at rest with optional KMS keys

### Operational Benefits
- **Separate State Files**: Each environment isolated for safety
- **Remote State Support**: S3 backend with DynamoDB locking
- **Health Check Tuning**: Environment-specific health check parameters
- **Resource Tagging**: Comprehensive tagging for cost allocation and management

## Deployment Steps

### Prerequisites

1. **AWS CLI Configuration**:
   - AWS CLI installed and configured with a named profile (recommended)
   - Example: `aws configure --profile hogtown`
   - Ensure the profile has appropriate permissions for:
     - S3 bucket creation and management
     - DynamoDB table creation
     - RDS instance management
     - App Runner service management
     - IAM role creation
     - VPC connector management

### Backend Infrastructure Setup

You have two options for setting up the required S3 buckets and DynamoDB tables:

#### Option 1: Automated Setup (Recommended)

Use the provided bootstrap script to automatically create all required AWS resources:

**Basic Usage:**
```bash
# Quick setup with auto-generated unique prefix
./bootstrap-terraform-backend.sh

# Get detailed help and see all examples
./bootstrap-terraform-backend.sh --help
```

**Advanced Usage Examples:**
```bash
# Custom prefix and region
./bootstrap-terraform-backend.sh --prefix mycompany-hogtown-456 --region us-west-2

# Complete setup with all options specified
./bootstrap-terraform-backend.sh \
  --prefix myproject-123 \
  --region us-east-1 \
  --profile production \
  --github-url https://github.com/your-username/your-repo

# Using short form arguments for quick setup
./bootstrap-terraform-backend.sh -p myproject-789 -r eu-west-1 -g https://github.com/user/repo

# Use with a specific AWS profile (useful for multiple AWS accounts)
./bootstrap-terraform-backend.sh --profile staging --prefix staging-env-001
```

**Complete Argument Reference:**
| Argument | Short | Description | Default | Example |
|----------|-------|-------------|---------|---------|
| `--prefix` | `-p` | Unique prefix for AWS resources | Auto-generated | `myproject-123` |
| `--region` | `-r` | AWS region | `us-east-1` | `us-west-2` |
| `--profile` | | AWS CLI profile | `default` | `production` |
| `--github-url` | `-g` | GitHub repository URL | None | `https://github.com/user/repo` |
| `--help` | `-h` | Show help and usage examples | | |

**What the script automatically does:**
- ✅ **Validates AWS credentials** before making any changes
- ✅ **Creates S3 buckets** with versioning and encryption enabled
- ✅ **Creates DynamoDB tables** for state locking with proper configuration
- ✅ **Generates configuration files** from templates in the `config/` directory
- ✅ **Updates GitHub URLs** in tfvars files (if provided)
- ✅ **Provides next steps** with exact commands to run
- ✅ **Uses unique prefixes** to avoid naming conflicts with other users

**Generated Files:**
- `config/shared.tfbackend` - Backend config for shared infrastructure
- `config/staging.tfbackend` - Backend config for staging environment  
- `config/prod.tfbackend` - Backend config for production environment
- `config/shared.tfvars` - Variables for shared infrastructure deployment
- `config/staging.tfvars` - Variables for staging deployment
- `config/prod.tfvars` - Variables for production deployment

#### Option 2: Manual Setup

If you need to create your own infrastructure manually:

**Create Required S3 Buckets and DynamoDB Tables**:
   
   **Important**: These resources must be created before running Terraform as they store the Terraform state files. Use your own unique bucket names to avoid conflicts.

   ```bash
   # Replace YOUR_UNIQUE_PREFIX with something unique to you (e.g., your-name-hogtown)
   export BUCKET_PREFIX="YOUR_UNIQUE_PREFIX"
   export AWS_REGION="us-east-1"
   export AWS_PROFILE="your-profile-name"

   # Create S3 buckets for Terraform state (use your own unique names)
   aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-shared --region ${AWS_REGION} --profile ${AWS_PROFILE}
   aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-staging --region ${AWS_REGION} --profile ${AWS_PROFILE}
   aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-prod --region ${AWS_REGION} --profile ${AWS_PROFILE}

   # Enable versioning on state buckets for state history
   aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-shared --versioning-configuration Status=Enabled --profile ${AWS_PROFILE}
   aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-staging --versioning-configuration Status=Enabled --profile ${AWS_PROFILE}
   aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-prod --versioning-configuration Status=Enabled --profile ${AWS_PROFILE}

   # Enable server-side encryption on state buckets
   aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-shared --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --profile ${AWS_PROFILE}
   aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-staging --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --profile ${AWS_PROFILE}
   aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-prod --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' --profile ${AWS_PROFILE}

   # Create DynamoDB tables for state locking (use your own unique names)
   aws dynamodb create-table \
     --table-name ${BUCKET_PREFIX}-terraform-locks-shared \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ${AWS_REGION} \
     --profile ${AWS_PROFILE}

   aws dynamodb create-table \
     --table-name ${BUCKET_PREFIX}-terraform-locks-staging \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ${AWS_REGION} \
     --profile ${AWS_PROFILE}

   aws dynamodb create-table \
     --table-name ${BUCKET_PREFIX}-terraform-locks-prod \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ${AWS_REGION} \
     --profile ${AWS_PROFILE}
   ```

**Configure Backend and Variables**:
   Copy the example configuration files and customize them with your settings:
   ```bash
   # Copy backend configuration files
   cd config
   cp shared.tfbackend.example shared.tfbackend
   cp staging.tfbackend.example staging.tfbackend  
   cp prod.tfbackend.example prod.tfbackend
   # Edit each .tfbackend file with your unique bucket names

   # Copy variable files
   cp shared.tfvars.example shared.tfvars
   cp staging.tfvars.example staging.tfvars
   cp prod.tfvars.example prod.tfvars
   # Edit each .tfvars file with:
   # - aws_profile: Your AWS CLI profile name (e.g., "hogtown")
   # - shared_state_bucket: Your unique shared state bucket name  
   # - github_repository_url: Your GitHub repository URL (staging/prod only)
   # - Other optional settings as needed
   ```

   **Important**: Both staging and prod environments must use the same `shared_state_bucket` value to access the shared infrastructure state.

### Terraform Deployment

Once you have the S3 buckets, DynamoDB tables, and configuration files set up (either via the bootstrap script or manually), you can deploy the infrastructure:

### 1. Deploy Shared Infrastructure

```bash
cd terraform/shared
terraform init -backend-config-file=../../config/shared.tfbackend
terraform plan -var-file=../../config/shared.tfvars
terraform apply -var-file=../../config/shared.tfvars
```

**Creates:**
- RDS PostgreSQL instance with security groups
- GitHub connection (requires manual authorization)
- Master database credentials in Secrets Manager

### 2. Deploy Environment-Specific Infrastructure

**Important**: The staging and prod environments require access to the shared infrastructure state. Make sure your `config/staging.tfvars` and `config/prod.tfvars` files contain the correct `shared_state_bucket` value.

```bash
# Deploy staging environment
cd terraform/environments/staging
terraform init -backend-config-file=../../config/staging.tfbackend
terraform plan -var-file=../../config/staging.tfvars
terraform apply -var-file=../../config/staging.tfvars

# Deploy production environment
cd ../prod
terraform init -backend-config-file=../../config/prod.tfbackend
terraform plan -var-file=../../config/prod.tfvars
terraform apply -var-file=../../config/prod.tfvars
```

## Configuration Variables

### Production Settings (Recommended)
```hcl
# terraform/shared/terraform.tfvars
multi_az = true
monitoring_interval = 60
performance_insights_enabled = true
deletion_protection = true
skip_final_snapshot = false
db_instance_class = "db.t4g.small"
```

### Environment Differences

| Setting | Staging | Production |
|---------|---------|------------|
| Branch | `develop` | `main` |
| Auto-deploy | `true` | `false` |
| Resources | 0.25 vCPU, 0.5 GB | 0.5 vCPU, 1 GB |
| Log Retention | 7 days | 30 days |
| Observability | Disabled | Enabled |
| Health Checks | Relaxed | Strict |

## Security Model

### Network Security
- RDS in private subnets (default VPC or custom VPC)
- App Runner VPC connector for database access
- Security groups restrict traffic to necessary ports only

### Access Control
- App Runner service roles with minimal permissions
- Secrets Manager access limited to specific secrets
- No public access to RDS instance

### Credential Management
- Master RDS credentials in Secrets Manager
- Environment-specific database users with separate passwords
- Automatic credential rotation supported

## Monitoring & Observability

### CloudWatch Integration
- Application logs with configurable retention
- RDS Enhanced Monitoring (optional)
- Performance Insights for query analysis

### Health Checks
- Configurable endpoints and thresholds
- Environment-specific tuning
- Automatic service recovery

## Cleanup

**Important:** Destroy in reverse order to avoid dependency issues.

```bash
# Destroy production environment
cd terraform/environments/prod
terraform destroy

# Destroy staging environment  
cd ../staging
terraform destroy

# Destroy shared infrastructure
cd ../../shared
terraform destroy
```

## Troubleshooting

### GitHub Connection Issues
- Manual authorization required in AWS console after first deployment
- Connection status available in Terraform outputs

### Database Connection Issues
- Verify VPC connector is enabled and properly configured
- Check security group rules allow App Runner to RDS access
- Validate Secrets Manager permissions

### App Runner Deployment Failures
- Check CloudWatch logs for application errors
- Verify `apprunner.yaml` configuration
- Ensure database migrations complete successfully

## Cost Optimization

### Development/Testing
- Use `db.t4g.micro` for RDS
- Disable Multi-AZ and monitoring
- Shorter log retention periods

### Production
- Enable Multi-AZ for high availability
- Use Performance Insights for optimization
- Consider Reserved Instances for predictable workloads

This architecture provides a production-ready foundation that can scale from development through enterprise deployments while maintaining security and operational best practices.