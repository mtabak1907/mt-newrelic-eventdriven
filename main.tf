# -------------------------------------------
# AWS Provider
# -------------------------------------------
provider "aws" {
  region = "eu-west-2" # London region
}

# -------------------------------------------
# IAM Role for Lambda Function
# -------------------------------------------
resource "aws_iam_role" "mt_2025v3" {
  name                 = "mt-2025v3"
  description          = "IAM Role for Lambda to execute and use SSM"
  max_session_duration = 3600

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# -------------------------------------------
# Attach SSM Policies to IAM Role
# -------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_full_access" {
  role       = aws_iam_role.mt_2025v3.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.mt_2025v3.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -------------------------------------------
# IAM Instance Profile for EC2 (Optional)
# -------------------------------------------
resource "aws_iam_instance_profile" "mt_2025v3_profile" {
  name = "mt-2025v3"
  role = aws_iam_role.mt_2025v3.name
}

# -------------------------------------------
# Lambda Function via Module (uses GitHub repo)
# -------------------------------------------
module "my_lambda_function" {
  source                    = "./module/lambda"
  name                      = "mt-relogin-vm-lambdav3"
  lambda_runtime            = "python3.9"
  lambda_handler            = "lambda.lambda_handler"
  lambda_code_s3_key        = "mt-lambda/lambda" # S3 key without .zip (not used when GitHub is used)
  s3_bucket_name            = "mt-s3-lon"
  create_s3_bucket          = false
  lambda_execution_role_arn = aws_iam_role.mt_2025v3.arn

  # GitHub Source Setup
  source_github_name         = "aws-lambda-restart-vm"
  source_github_organization = "mtabak1907"

  # Hash for the Lambda code
  source_code_hash = "vDQcZJk/oRJcS8BgpPsil/4avzX43wYfiYcHiysNHl0="

  # Networking (VPC not used here)
  subnet_ids         = []
  security_group_ids = []

  # Lambda Environment Variables
  environment_variables = {
    INSTANCE_IDS = "i-0cca2e61e3dac33fb,i-0971f52241345333b"
  }

  memory_size = 128
  timeout     = 10

  tags = {
    Name        = "mt-relogin-vm-lambdav3"
    Environment = "mt-staging"
  }
}

# -------------------------------------------
# API Gateway HTTP API
# -------------------------------------------
resource "aws_apigatewayv2_api" "mt_relogin_vm_api" {
  name          = "mt-relogin-vmv3"
  protocol_type = "HTTP"
}

# -------------------------------------------
# API Gateway Integration with Lambda
# -------------------------------------------
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.mt_relogin_vm_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = module.my_lambda_function.lambda_invoke_arn
}

# -------------------------------------------
# API Gateway Route
# -------------------------------------------
resource "aws_apigatewayv2_route" "relogin_route" {
  api_id    = aws_apigatewayv2_api.mt_relogin_vm_api.id
  route_key = "POST /relogin"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# -------------------------------------------
# API Gateway Stage
# -------------------------------------------
resource "aws_apigatewayv2_stage" "mt_relogin_vm_stage" {
  api_id      = aws_apigatewayv2_api.mt_relogin_vm_api.id
  name        = "prod"
  auto_deploy = true
}

# -------------------------------------------
# Lambda Permission for API Gateway
# -------------------------------------------
resource "aws_lambda_permission" "apigateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.my_lambda_function.lambda_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.mt_relogin_vm_api.execution_arn}/*/*"
}

# -------------------------------------------
# Output the API endpoint
# -------------------------------------------
output "api_url" {
  value = "${aws_apigatewayv2_stage.mt_relogin_vm_stage.invoke_url}/relogin"
}
