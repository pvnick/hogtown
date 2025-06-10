# Backend configuration for production environment
terraform {
  backend "s3" {
    bucket         = "hogtown-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks-prod"
  }
}