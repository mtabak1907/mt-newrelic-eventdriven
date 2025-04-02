resource "local_file" "this_java" {
  count    = length(regexall("java", var.lambda_runtime)) > 0 ? 1 : 0
  filename = "${path.module}/${var.lambda_code_s3_key}.java"
  content  = file("${path.module}/dummy_java.java")
}

data "archive_file" "this_java" {
  count       = length(regexall("java", var.lambda_runtime)) > 0 ? 1 : 0
  type        = "zip"
  source_file = local_file.this_java[0].filename
  output_path = "${path.module}/${var.lambda_code_s3_key}.zip"
}

# Upload the java file to S3 if java runtime is selected
resource "aws_s3_object" "java_lambda_code" {
  # Only create this resource if the runtime is java
  count  = length(regexall("java", var.lambda_runtime)) > 0 ? 1 : 0
  bucket = var.create_s3_bucket ? aws_s3_bucket.this[0].id : var.s3_bucket_name
  key    = var.folder_name != "" ? "/${var.folder_name}/${var.lambda_code_s3_key}.zip" : "${var.lambda_code_s3_key}.zip"
  source = data.archive_file.this_java[0].output_path
  lifecycle {
    ignore_changes = [source]
  }
}