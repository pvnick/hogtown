#!/bin/bash

# Terraform Backend Bootstrap Script
# This script creates the S3 buckets and DynamoDB tables needed for Terraform remote state
# and generates the backend configuration files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --prefix PREFIX        Unique prefix for AWS resources (default: hogtown-\$(date +%s | tail -c 6))"
    echo "  -r, --region REGION        AWS region (default: us-east-1)"
    echo "  --profile PROFILE          AWS CLI profile to use (default: default)"
    echo "  -g, --github-url URL       GitHub repository URL (optional)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                                    # Use defaults"
    echo "  $0 --prefix myproject-123 --region us-west-2         # Custom prefix and region"
    echo "  $0 --profile myprofile --github-url https://github.com/user/repo"
    echo ""
}

# Default values
DEFAULT_PREFIX="hogtown-$(date +%s | tail -c 6)"
PREFIX=""
REGION="us-east-1"
AWS_PROFILE="default"
GITHUB_URL=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -g|--github-url)
            GITHUB_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Use default prefix if not provided
if [[ -z "$PREFIX" ]]; then
    PREFIX="$DEFAULT_PREFIX"
fi

print_status "Starting Terraform backend bootstrap..."
print_status "Prefix: $PREFIX"
print_status "Region: $REGION"
print_status "AWS Profile: $AWS_PROFILE"

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Test AWS credentials
print_status "Testing AWS credentials..."
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
    print_error "AWS credentials not configured for profile '$AWS_PROFILE'. Please run 'aws configure --profile $AWS_PROFILE'"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
print_success "AWS credentials verified for account: $ACCOUNT_ID"

# Define resource names
SHARED_BUCKET="${PREFIX}-terraform-state-shared"
STAGING_BUCKET="${PREFIX}-terraform-state-staging"
PROD_BUCKET="${PREFIX}-terraform-state-prod"
SHARED_TABLE="${PREFIX}-terraform-locks-shared"
STAGING_TABLE="${PREFIX}-terraform-locks-staging"
PROD_TABLE="${PREFIX}-terraform-locks-prod"

print_status "Creating S3 buckets..."

# Create S3 buckets
for bucket in "$SHARED_BUCKET" "$STAGING_BUCKET" "$PROD_BUCKET"; do
    print_status "Creating bucket: $bucket"
    if aws s3 mb "s3://$bucket" --region "$REGION" --profile "$AWS_PROFILE"; then
        print_success "Created bucket: $bucket"
    else
        print_error "Failed to create bucket: $bucket"
        exit 1
    fi
done

print_status "Configuring S3 bucket settings..."

# Configure S3 buckets (versioning and encryption)
for bucket in "$SHARED_BUCKET" "$STAGING_BUCKET" "$PROD_BUCKET"; do
    print_status "Enabling versioning on: $bucket"
    aws s3api put-bucket-versioning \
        --bucket "$bucket" \
        --versioning-configuration Status=Enabled \
        --profile "$AWS_PROFILE"
    
    print_status "Enabling encryption on: $bucket"
    aws s3api put-bucket-encryption \
        --bucket "$bucket" \
        --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' \
        --profile "$AWS_PROFILE"
done

print_success "S3 buckets configured successfully"

print_status "Creating DynamoDB tables..."

# Create DynamoDB tables
for table in "$SHARED_TABLE" "$STAGING_TABLE" "$PROD_TABLE"; do
    print_status "Creating DynamoDB table: $table"
    if aws dynamodb create-table \
        --table-name "$table" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --profile "$AWS_PROFILE" > /dev/null; then
        print_success "Created DynamoDB table: $table"
    else
        print_error "Failed to create DynamoDB table: $table"
        exit 1
    fi
done

print_status "Waiting for DynamoDB tables to become active..."
for table in "$SHARED_TABLE" "$STAGING_TABLE" "$PROD_TABLE"; do
    aws dynamodb wait table-exists --table-name "$table" --region "$REGION" --profile "$AWS_PROFILE"
done
print_success "All DynamoDB tables are active"

# Get the terraform directory path relative to the script location
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create config directory if it doesn't exist
mkdir -p "$TERRAFORM_DIR/config"

print_status "Generating backend configuration files..."

# Check if example files exist
if [[ ! -f "$TERRAFORM_DIR/config/shared.tfbackend.example" ]]; then
    print_error "Example file $TERRAFORM_DIR/config/shared.tfbackend.example not found!"
    exit 1
fi

# Generate backend configuration files by copying examples and replacing placeholders
for env in shared staging prod; do
    print_status "Generating ${env}.tfbackend from example..."
    cp "$TERRAFORM_DIR/config/${env}.tfbackend.example" "$TERRAFORM_DIR/config/${env}.tfbackend"
    
    # Replace placeholders in the copied file
    sed -i "s/YOUR_UNIQUE_PREFIX/${PREFIX}/g" "$TERRAFORM_DIR/config/${env}.tfbackend"
    sed -i "s/us-east-1/${REGION}/g" "$TERRAFORM_DIR/config/${env}.tfbackend"
    sed -i "s/default/${AWS_PROFILE}/g" "$TERRAFORM_DIR/config/${env}.tfbackend"
    
    # Add generation comment
    sed -i "1i# Generated by bootstrap-terraform-backend.sh on $(date)" "$TERRAFORM_DIR/config/${env}.tfbackend"
done

print_success "Backend configuration files generated"

print_status "Generating variable files..."

# Generate variable files by copying examples and replacing placeholders
for env in shared staging prod; do
    print_status "Generating ${env}.yaml from example..."
    cp "$TERRAFORM_DIR/config/${env}.yaml.example" "$TERRAFORM_DIR/config/${env}.yaml"
    
    # Replace placeholders in the copied file
    sed -i "s/YOUR_UNIQUE_PREFIX/${PREFIX}/g" "$TERRAFORM_DIR/config/${env}.yaml"
    sed -i "s/us-east-1/${REGION}/g" "$TERRAFORM_DIR/config/${env}.yaml"
    sed -i "s/your-aws-profile-name/${AWS_PROFILE}/g" "$TERRAFORM_DIR/config/${env}.yaml"
    
    # Update GitHub URL if provided (shared environment only)
    if [[ -n "$GITHUB_URL" && "$env" == "shared" ]]; then
        sed -i "s|https://github.com/your-username/your-repo-name|${GITHUB_URL}|g" "$TERRAFORM_DIR/config/${env}.yaml"
        sed -i "s/# GitHub repository URL for App Runner source connection/# GitHub repository URL for App Runner source connection (provided via --github-url)/g" "$TERRAFORM_DIR/config/${env}.yaml"
    fi
    
    # Add generation comment
    sed -i "1i# Generated by bootstrap-terraform-backend.sh on $(date)" "$TERRAFORM_DIR/config/${env}.yaml"
done

print_success "Variable files generated"

# Summary
echo ""
print_success "🎉 Terraform backend bootstrap completed successfully!"
echo ""
echo "📦 Created AWS Resources:"
echo "   S3 Buckets:"
echo "     - $SHARED_BUCKET (shared infrastructure state)"
echo "     - $STAGING_BUCKET (staging environment state)"
echo "     - $PROD_BUCKET (production environment state)"
echo ""
echo "   DynamoDB Tables:"
echo "     - $SHARED_TABLE (shared infrastructure locking)"
echo "     - $STAGING_TABLE (staging environment locking)"
echo "     - $PROD_TABLE (production environment locking)"
echo ""
echo "📄 Generated Configuration Files:"
echo "   - terraform/config/shared.tfbackend"
echo "   - terraform/config/staging.tfbackend"
echo "   - terraform/config/prod.tfbackend"
echo "   - terraform/config/shared.yaml"
echo "   - terraform/config/staging.yaml"
echo "   - terraform/config/prod.yaml"
echo ""

if [[ -z "$GITHUB_URL" ]]; then
    print_warning "⚠️  Don't forget to update the GitHub repository URL in:"
    echo "   - terraform/config/shared.yaml"
    echo ""
fi

echo "🚀 Next Steps:"
echo "   1. Update GitHub repository URL in terraform/config/shared.yaml (if not provided)"
echo "   2. Deploy shared infrastructure:"
echo "      cd terraform/shared"
echo "      terraform init -backend-config-file=../config/shared.tfbackend"
echo "      terraform apply"
echo ""
echo "   3. Deploy staging environment:"
echo "      cd terraform/environments/staging"
echo "      terraform init -backend-config-file=../../config/staging.tfbackend"
echo "      terraform apply"
echo ""
echo "   4. Deploy production environment:"
echo "      cd terraform/environments/prod"
echo "      terraform init -backend-config-file=../../config/prod.tfbackend"
echo "      terraform apply"
echo ""
print_success "Happy deploying! 🚀"