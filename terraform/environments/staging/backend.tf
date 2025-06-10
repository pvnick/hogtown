# Backend configuration for staging environment
terraform {
  backend "s3" {
    bucket         = "hogtown-terraform-state-staging"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks-staging"
  }
}