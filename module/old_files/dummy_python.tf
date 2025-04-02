resource "local_file" "this_python" {
  count    = length(regexall("python", var.lambda_runtime)) > 0 ? 1 : 0
  filename = "${path.module}/${var.lambda_code_s3_key}.py"
  content  = file("${path.module}/dummy_python.py")
}

data "archive_file" "this_python" {
  count       = length(regexall("python", var.lambda_runtime)) > 0 ? 1 : 0
  type        = "zip"
  source_file = local_file.this_python[0].filename
  output_path = "${path.module}/${var.lambda_code_s3_key}.zip"
}

# Upload the Python file to S3 if Python runtime is selected
resource "aws_s3_object" "python_lambda_code" {
  # Only create this resource if the runtime is Python
  count  = length(regexall("python", var.lambda_runtime)) > 0 ? 1 : 0
  bucket = var.create_s3_bucket ? aws_s3_bucket.this[0].id : var.s3_bucket_name
  key    = var.folder_name != "" ? "/${var.folder_name}/${var.lambda_code_s3_key}.zip" : "${var.lambda_code_s3_key}.zip"
  source = data.archive_file.this_python[0].output_path
  lifecycle {
    ignore_changes = [
      source
    ]
  }
}