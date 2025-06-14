terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Get current region and account for ARN construction
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Get default VPC or use provided VPC
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : false
}

# Get CIDR blocks for database subnets
data "aws_subnet" "database_subnets" {
  for_each = toset(var.database_subnet_ids)
  id       = each.value
}

# Get CIDR blocks for Lambda subnets if provided
data "aws_subnet" "lambda_subnets" {
  for_each = toset(var.lambda_subnet_ids)
  id       = each.value
}

# Use only user-provided security groups (Lambda access handled separately)
locals {
  all_allowed_security_groups = var.allowed_security_groups
  lambda_subnet_cidrs = [for subnet in data.aws_subnet.lambda_subnets : subnet.cidr_block]
}
