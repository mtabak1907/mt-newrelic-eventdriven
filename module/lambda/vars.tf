variable "name" {
  description = "Name of the function and resources"
  type        = string
}

variable "description" {
  description = "Description of the Lambda"
  type        = string
  default     = ""
}

variable "create_s3_bucket" {
  description = "Creates a dedicated S3 bucket for code storage"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Uses a provided S3 bucket name for code storage"
  type        = string
  default     = ""
}

variable "folder_name" {
  description = "Stores the code in provided folder name within the S3 bucket"
  type        = string
  default     = ""
}

###MT added
variable "lambda_execution_role_arn" {
  description = "IAM role ARN to assign to the Lambda function"
  type        = string
}
###

variable "memory_size" {
  description = "Amount of memory to allocate to the Lambda in MBs"
  type        = number
  default     = 128
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "The memory_size must be between 128 and 10240 MB in 1-MB increments."
  }
}

variable "lambda_runtime" {
  description = "The runtime environment for the Lambda function (e.g., python3.8, dotnetcore3.1, nodejs14.x, java11)"
  type        = string
}

variable "lambda_handler" {
  description = "The handler for the Lambda function"
  type        = string
  default     = ""
}

variable "lambda_code_s3_key" {
  description = "S3 key for the Lambda function code"
  type        = string
  default     = "lambda_function"

  validation {
    condition     = !(length(var.lambda_code_s3_key) >= 4 && substr(var.lambda_code_s3_key, length(var.lambda_code_s3_key) - 4, 4) == ".zip")
    error_message = "The S3 key should not end with '.zip'. Please provide a key without this extension."
  }
}

variable "log_retention_in_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}

variable "tags" {
  description = "A map of tags to apply to the resources"
  type        = map(any)
}

variable "subnet_ids" {
  description = "Subnet IDs for the lambda's execution"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security Group IDs to attach to the lambda's execution"
  type        = list(string)
}

variable "source_github_name" {
  description = "Name of the Github repository where the code comes from"
  type        = string
  default     = ""
}

variable "source_github_organization" {
  description = "Name of the Github organization where the code comes from"
  type        = string
  default     = "IntelexTechnologies"
}

variable "source_github_additional_iam_policies" {
  description = "Additional IAM policy JSONs to add to the Github IAM role"
  type        = list(string)
  default     = []
}

variable "additional_iam_policies" {
  description = "A list of additional JSON policy documents to attach to the Lambda execution role"
  type        = list(string)
  default     = []
}

variable "dead_letter_arn" {
  description = "String, ARN of the SNS topic or SQS queue to notify when invocation fails."
  type        = string
  default     = ""

  validation {
    condition     = length(var.dead_letter_arn) == 0 || can(regexall("^arn:aws:(sns|sqs):.*$", var.dead_letter_arn))
    error_message = "dead_letter_arn must be an empty string or a valid ARN of an SNS topic or SQS queue."
  }
}


variable "ephemeral_storage_size" {
  description = "Size allocated to the /tmp storage"
  type        = number
  default     = 512

  validation {
    condition     = var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240
    error_message = "The ephemeral_storage_size must be between 512 and 10240."
  }
}


variable "application_log_level" {
  description = "The logging level for application logs"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.application_log_level)
    error_message = "The application_log_level must be one of these: TRACE DEBUG INFO WARN ERROR FATAL"
  }
}

variable "system_log_level" {
  description = "The logging level for system logs"
  type        = string
  default     = "WARN"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN"], var.system_log_level)
    error_message = "The system_log_level must be one of these: DEBUG, INFO, WARN"
  }
}

variable "timeout" {
  description = "Timeout execution for the Lambda"
  type        = number
  default     = 5
}

variable "environment_variables" {
  description = "Environment variables for the lambda"
  type        = map(any)
  default     = {}
}

variable "concurrency_limit" {
  description = "Lambda concurrency execution limit. (-1 for unreserved)"
  type        = number
  default     = -1
}

variable "tracing" {
  description = "The tracing mode for the Lambda function"
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "PassThrough", "Active"], var.tracing)
    error_message = "The tracing variable must be one of: '', 'PassThrough', 'Active'."
  }
}
##MT ADDED
variable "source_code_hash" {
  description = "SHA256 hash of the Lambda deployment package"
  type        = string
}
