terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Invoke Lambda function to create databases
resource "null_resource" "invoke_db_setup" {
  triggers = {
    environment_databases = join(",", var.environment_databases)
    lambda_function_name  = var.lambda_function_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws lambda invoke \
        ${var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""} \
        --function-name ${var.lambda_function_name} \
        --payload '${jsonencode({
          action = "create_database"
          rds_secret_arn = var.rds_secrets_manager_arn
          project_name = var.project_name
          environment_databases = var.environment_databases
        })}' \
        --cli-binary-format raw-in-base64-out \
        response.json
      
      if [ $? -ne 0 ]; then
        echo "Lambda invocation failed"
        exit 1
      fi
      
      # Check response for errors
      if grep -q '"statusCode": 500' response.json; then
        echo "Lambda function returned error:"
        cat response.json
        exit 1
      fi
      
      echo "Database setup completed successfully"
      cat response.json
      rm -f response.json
    EOT
  }
}

# Data source to get the created secret ARNs
data "aws_secretsmanager_secret" "env_db_secrets" {
  for_each = toset(var.environment_databases)
  name     = "${var.project_name}/database/${each.value}"
  
  depends_on = [null_resource.invoke_db_setup]
}