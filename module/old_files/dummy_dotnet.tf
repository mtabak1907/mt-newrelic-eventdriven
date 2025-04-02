resource "local_file" "this_dotnet" {
  count    = length(regexall("dotnet", var.lambda_runtime)) > 0 ? 1 : 0
  filename = "${path.module}/${var.lambda_code_s3_key}.cs"
  content  = file("${path.module}/dummy_dotnet.cs")
}

data "archive_file" "this_dotnet" {
  count       = length(regexall("dotnet", var.lambda_runtime)) > 0 ? 1 : 0
  type        = "zip"
  source_file = local_file.this_dotnet[0].filename
  output_path = "${path.module}/${var.lambda_code_s3_key}.zip"
}

# Upload the dotnet file to S3 if dotnet runtime is selected
resource "aws_s3_object" "dotnet_lambda_code" {
  # Only create this resource if the runtime is dotnet
  count  = length(regexall("dotnet", var.lambda_runtime)) > 0 ? 1 : 0
  bucket = var.create_s3_bucket ? aws_s3_bucket.this[0].id : var.s3_bucket_name
  key    = var.folder_name != "" ? "/${var.folder_name}/${var.lambda_code_s3_key}.zip" : "${var.lambda_code_s3_key}.zip"
  source = data.archive_file.this_dotnet[0].output_path
  lifecycle {
    ignore_changes = [source]
  }
}