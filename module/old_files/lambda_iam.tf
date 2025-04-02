# Create IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda-${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.this_lambda_assume.json
  tags               = var.tags
}

# Data source to define the IAM assume role policy document for Lambda
data "aws_iam_policy_document" "this_lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "this_lambda" {
  name   = "lambda-${var.name}-policy"
  policy = data.aws_iam_policy_document.this_lambda_execution.json
}

data "aws_iam_policy_document" "this_lambda_execution" {

  #checkov:skip=CKV_AWS_111:IAM permissions to be redefined later
  #checkov:skip=CKV_AWS_356:IAM permissions to be redefined later
  # statement {
  #   effect = "Allow"
  #   actions = [
  #     "s3:GetObject",
  #     "s3:ListBucket"
  #   ]
  #   resources = [
  #     "${aws_s3_bucket.this.arn}",
  #     "${aws_s3_bucket.this.arn}/*"
  #   ]
  # }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.lambda_log_group.arn}"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt"
    ]
    resources = [
      "${aws_kms_key.this.arn}"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy_attachment" "this_lambda_execution" {
  policy_arn = aws_iam_policy.this_lambda.arn
  role       = aws_iam_role.lambda_execution_role.name
}


# Attach additional IAM policies to the Lambda execution role
resource "aws_iam_role_policy" "additional_policies" {
  count  = length(var.additional_iam_policies)
  name   = "lambda-${var.name}-policy-${count.index}"
  role   = aws_iam_role.lambda_execution_role.name
  policy = element(var.additional_iam_policies, count.index)
}

# Dead Letter IAM policy
#automatically grant the sns or sqs functionality if the detter letter queue exists
data "aws_iam_policy_document" "this_dead_letter" {
  count = var.dead_letter_arn != "" ? 1 : 0
  dynamic "statement" {
    for_each = length(var.dead_letter_arn) > 0 && (can(regexall("sns", var.dead_letter_arn)) || can(regexall("sqs", var.dead_letter_arn))) ? [1] : []

    content {
      effect = "Allow"
      actions = [
        can(regexall("sns", var.dead_letter_arn)) ? "sns:Publish" : "sqs:SendMessage"
      ]
      resources = [
        var.dead_letter_arn
      ]
    }
  }
}

#attach the policy
resource "aws_iam_role_policy" "this_dead_letter" {
  count  = var.dead_letter_arn != "" ? 1 : 0
  name   = "lambda-${var.name}-dead-letter-policy"
  role   = aws_iam_role.lambda_execution_role.name
  policy = data.aws_iam_policy_document.this_dead_letter[0].json
}