terraform {
  backend "s3" {
    # Backend configuration is provided via -backend-config flag
    # pointing to config/prod.tfbackend file
    #
    # Example usage:
    # terraform init -backend-config=../../config/prod.tfbackend
  }
}
