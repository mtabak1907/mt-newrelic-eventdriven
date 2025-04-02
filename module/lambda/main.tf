locals {
  lambda_handler = length(regexall("python", var.lambda_runtime)) > 0 ? "${var.lambda_code_s3_key}.lambda_handler" : length(regexall("dotnet", var.lambda_runtime)) > 0 ? "Handler::LambdaFunction.Handler::handleRequest" : length(regexall("nodejs", var.lambda_runtime)) > 0 ? "index.handler" : length(regexall("java", var.lambda_runtime)) > 0 ? "Handler::handleRequest" : ""
}

# Create Lambda function
resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_272: Code signing to be done in a future state
  function_name                  = var.name
  description                    = var.description != "" ? var.description : "${var.name} Lambda function created by the Terraform Registry"
#  role                           = aws_iam_role.lambda_execution_role.arn
  role                           = var.lambda_execution_role_arn ##MT added
  source_code_hash               = var.source_code_hash ##MTAdded
  handler                        = var.lambda_handler != "" ? var.lambda_handler : local.lambda_handler
  runtime                        = var.lambda_runtime
  reserved_concurrent_executions = var.concurrency_limit
  s3_bucket                      = var.create_s3_bucket ? aws_s3_bucket.this[0].id : var.s3_bucket_name
  s3_key                         = var.folder_name != "" ? "/${var.folder_name}/${var.lambda_code_s3_key}.zip" : "${var.lambda_code_s3_key}.zip"
  timeout                        = var.timeout
  tags                           = var.tags
  kms_key_arn                    = aws_kms_key.this.arn
  memory_size                    = var.memory_size
  
  dynamic "tracing_config" {
    for_each = var.tracing != "" ? [1] : []
    content {
      mode = var.tracing
    }
  }

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  logging_config {
    application_log_level = var.application_log_level
    system_log_level      = var.system_log_level
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.lambda_log_group.name
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_arn != "" ? [1] : []
    content {
      target_arn = var.dead_letter_arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = var.environment_variables
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group
  ]
}

# Create S3 bucket
resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV2_AWS_6: False flag due to optional bucket
  count  = var.create_s3_bucket ? 1 : 0
  bucket = lower("ilx-lambda-${random_string.this[0].id}-${var.name}")
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.this[0].id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.this.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count                   = var.create_s3_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  #checkov:skip=CKV_AWS_338: Logs are to be configured for however long the user wants them to be
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_kms_key" "this" {
  #checkov:skip=CKV2_AWS_64: KMS Key policies to be determined later
  description         = "${var.name} Lambda key"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/lambda-${var.name}-key"
  target_key_id = aws_kms_key.this.key_id
}

resource "random_string" "this" {
  count   = var.create_s3_bucket ? 1 : 0
  length  = 4
  special = false
}