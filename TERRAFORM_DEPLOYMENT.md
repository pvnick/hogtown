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
│   ├── backend.tf.example    # Example backend configuration
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── environments/
│   ├── staging/              # Staging App Runner service
│   │   ├── backend.tf.example        # Example backend configuration
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/                 # Production App Runner service
│       ├── backend.tf.example
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
   Ensure AWS CLI is configured with appropriate permissions for:
   - S3 bucket creation and management
   - DynamoDB table creation
   - RDS instance management
   - App Runner service management
   - IAM role creation
   - VPC connector management

2. **Create Required S3 Buckets and DynamoDB Tables**:
   
   **Important**: These resources must be created before running Terraform as they store the Terraform state files. Use your own unique bucket names to avoid conflicts.

   ```bash
   # Replace YOUR_UNIQUE_PREFIX with something unique to you (e.g., your-name-hogtown)
   export BUCKET_PREFIX="YOUR_UNIQUE_PREFIX"
   export AWS_REGION="us-east-1"

   # Create S3 buckets for Terraform state (use your own unique names)
   aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-shared --region ${AWS_REGION}
   aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-staging --region ${AWS_REGION}
   aws s3 mb s3://${BUCKET_PREFIX}-terraform-state-prod --region ${AWS_REGION}

   # Enable versioning on state buckets for state history
   aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-shared --versioning-configuration Status=Enabled
   aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-staging --versioning-configuration Status=Enabled
   aws s3api put-bucket-versioning --bucket ${BUCKET_PREFIX}-terraform-state-prod --versioning-configuration Status=Enabled

   # Enable server-side encryption on state buckets
   aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-shared --server-side-encryption-configuration '{
     "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
   }'
   aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-staging --server-side-encryption-configuration '{
     "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
   }'
   aws s3api put-bucket-encryption --bucket ${BUCKET_PREFIX}-terraform-state-prod --server-side-encryption-configuration '{
     "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
   }'

   # Create DynamoDB tables for state locking (use your own unique names)
   aws dynamodb create-table \
     --table-name ${BUCKET_PREFIX}-terraform-locks-shared \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ${AWS_REGION}

   aws dynamodb create-table \
     --table-name ${BUCKET_PREFIX}-terraform-locks-staging \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ${AWS_REGION}

   aws dynamodb create-table \
     --table-name ${BUCKET_PREFIX}-terraform-locks-prod \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region ${AWS_REGION}
   ```

3. **Configure Backend and Variables**:
   Copy the example configuration files and customize them with your settings:
   ```bash
   # Copy backend configuration files
   cd config
   cp shared.tfbackend.example shared.tfbackend
   cp staging.tfbackend.example staging.tfbackend  
   cp prod.tfbackend.example prod.tfbackend
   # Edit each .tfbackend file with your unique bucket names

   # Copy variable files
   cp staging.tfvars.example staging.tfvars
   cp prod.tfvars.example prod.tfvars
   # Edit each .tfvars file with:
   # - shared_state_bucket: Your unique shared state bucket name  
   # - github_repository_url: Your GitHub repository URL
   # - Other optional settings as needed
   ```

   **Important**: Both staging and prod environments must use the same `shared_state_bucket` value to access the shared infrastructure state.

### 1. Initialize Terraform

This project uses an S3 bucket to store the Terraform state. To avoid conflicts, you must use your own S3 bucket and DynamoDB table.

**Use the backend configuration files** from the `config/` directory. Initialize each environment from its respective directory using the `-backend-config-file` option.

Example for the shared environment:

```bash
cd terraform/shared
terraform init -backend-config-file=../../config/shared.tfbackend
```

This approach uses the backend configuration file you created in the `config/` directory, making the initialization process cleaner and more maintainable.

### 2. Deploy Shared Infrastructure

```bash
cd terraform/shared
# Initialize with your backend configuration (see above)
terraform init -backend-config-file=../../config/shared.tfbackend
terraform plan
terraform apply
```

**Creates:**
- RDS PostgreSQL instance with security groups
- GitHub connection (requires manual authorization)
- Master database credentials in Secrets Manager

### 3. Deploy Environment-Specific Infrastructure

**Important**: The staging and prod environments require access to the shared infrastructure state. Make sure your `config/staging.tfvars` and `config/prod.tfvars` files contain the correct `shared_state_bucket` value.

```bash
# Deploy staging environment
cd ../environments/staging

# Initialize with backend configuration file
terraform init -backend-config-file=../../config/staging.tfbackend

# Plan and apply using your variables file from config directory
# This will automatically access shared state using the shared_state_bucket variable
terraform plan -var-file=../../config/staging.tfvars
terraform apply -var-file=../../config/staging.tfvars

# Deploy production environment
cd ../prod

# Initialize with backend configuration file
terraform init -backend-config-file=../../config/prod.tfbackend

# Plan and apply using your variables file from config directory
# This will automatically access shared state using the shared_state_bucket variable
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