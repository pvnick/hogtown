# Backend configuration for shared infrastructure
terraform {
  backend "s3" {
    bucket         = "hogtown-terraform-state-shared"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks-shared"
  }
}

# S3 bucket for Terraform state (create this manually first)
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "PROJECT-terraform-state"
#   
#   lifecycle {
#     prevent_destroy = true
#   }
# }
# 
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
# 
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
# 
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
# 
# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
# 
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
# 
# # DynamoDB table for state locking
# resource "aws_dynamodb_table" "terraform_state_locks" {
#   name           = "terraform-state-locks"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"
# 
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# 
#   tags = {
#     Name = "Terraform State Locks"
#   }
# }