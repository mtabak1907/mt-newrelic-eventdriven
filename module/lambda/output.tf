output "lambda_function_arn" {
  description = "String, ARN of the lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_function_invoke_arn" {
  description = "String, ARN of the lambda function to invoke"
  value       = aws_lambda_function.this.invoke_arn
}

output "lambda_name" {
  description = "String, Name of the lambda function"
  value       = aws_lambda_function.this.function_name
}

#output "lambda_iam_execution_role" {
#  value = aws_iam_role.lambda_execution_role.arn
#}

output "s3_bucket_name" {
  description = "String, name of the S3 bucket if created"
  value       = var.create_s3_bucket ? aws_s3_bucket.this[0].id : ""
}

output "s3_bucket_arn" {
  description = "String, ARN of the S3 bucket if created"
  value       = var.create_s3_bucket ? aws_s3_bucket.this[0].arn : ""
}

#output "github_iam_role_arn" {
#  description = "ARN of the Github Actions IAM role, if created"
#  value       = var.source_github_name != "" ? aws_iam_role.this_github[0].arn : ""
#}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}
