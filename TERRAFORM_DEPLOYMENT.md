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
│   │   ├── terraform.tfvars.example  # Example variables file
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/                 # Production App Runner service
│       ├── backend.tf.example
│       ├── terraform.tfvars.example
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── modules/
    ├── database/             # RDS instance with security
    ├── database-setup/       # Environment database creation
    └── apprunner/           # App Runner with VPC connector
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

3. **Configure Variables**:
   Copy the example variable files and customize them with your settings:
   ```bash
   # For staging environment
   cd terraform/environments/staging
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your GitHub repository URL and other settings

   # For production environment  
   cd ../prod
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your GitHub repository URL and other settings
   ```

### 1. Initialize Terraform

This project uses an S3 bucket to store the Terraform state. To avoid conflicts, you must use your own S3 bucket and DynamoDB table.

**Do not create a backend.tf file.** Instead, you will pass the configuration to Terraform during initialization. Run the init command for each environment (shared, staging, prod) from its respective directory.

Example for the shared environment:

```bash
cd terraform/shared

terraform init \
    -backend-config="bucket=YOUR_UNIQUE_BUCKET_NAME" \
    -backend-config="key=hogtown/shared.tfstate" \
    -backend-config="region=YOUR_AWS_REGION" \
    -backend-config="dynamodb_table=YOUR_DYNAMODB_LOCK_TABLE_NAME"
```

Replace the placeholder values with the names of the S3 bucket and DynamoDB table you created in the bootstrap step. You will repeat this process for the staging and prod environments, changing the key value accordingly (e.g., `key=hogtown/staging.tfstate`).

### 2. Deploy Shared Infrastructure

```bash
cd terraform/shared
# Initialize with your backend configuration (see above)
terraform plan
terraform apply
```

**Creates:**
- RDS PostgreSQL instance with security groups
- GitHub connection (requires manual authorization)
- Master database credentials in Secrets Manager

### 3. Deploy Environment-Specific Infrastructure

```bash
# Deploy staging environment
cd ../environments/staging

# Initialize with backend configuration
terraform init \
    -backend-config="bucket=YOUR_UNIQUE_BUCKET_NAME" \
    -backend-config="key=hogtown/staging.tfstate" \
    -backend-config="region=YOUR_AWS_REGION" \
    -backend-config="dynamodb_table=YOUR_DYNAMODB_LOCK_TABLE_NAME"

# Plan and apply using your terraform.tfvars file
terraform plan
terraform apply

# Deploy production environment
cd ../prod

# Initialize with backend configuration
terraform init \
    -backend-config="bucket=YOUR_UNIQUE_BUCKET_NAME" \
    -backend-config="key=hogtown/prod.tfstate" \
    -backend-config="region=YOUR_AWS_REGION" \
    -backend-config="dynamodb_table=YOUR_DYNAMODB_LOCK_TABLE_NAME"

# Plan and apply using your terraform.tfvars file
terraform plan
terraform apply
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