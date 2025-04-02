#sts role
data "aws_iam_policy_document" "this_github_assume" {
  count = var.source_github_name != "" ? 1 : 0
  statement {
    sid    = "AllowAssumeRoleWithWebIdentity"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:oidc-provider/token.actions.githubusercontent.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values = [
        "sts.amazonaws.com",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.source_github_organization}/${var.source_github_name}/*",
        "repo:${var.source_github_organization}/*",
      ]
    }
  }
}

data "aws_iam_policy_document" "this_github_s3" {
  count = var.source_github_name != "" && var.create_s3_bucket ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.this[0].arn}/*", # Access to all objects in the bucket
      aws_s3_bucket.this[0].arn         # Access to the bucket itself (e.g., for listing objects)
    ]
  }
}

data "aws_iam_policy_document" "this_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Encrypt",
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.this.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:*"
    ]
    resources = [
      aws_lambda_function.this.arn
    ]
  }

  statement {
    sid    = "STSGetServiceBearerToken"
    effect = "Allow"

    actions = [
      "sts:GetServiceBearerToken",
    ]

    resources = [
      "*",
    ]

    condition {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"
      values = [
        "s3.amazonaws.com",
      ]
    }
  }
}

#role creation
resource "aws_iam_role" "this_github" {
  count              = var.source_github_name != "" ? 1 : 0
  name               = "github-${var.name}-actions-role"
  description        = "IAM Role for Github ${var.source_github_name} Actions"
  assume_role_policy = data.aws_iam_policy_document.this_github_assume[0].json
  tags               = var.tags
}

#policy creation
resource "aws_iam_role_policy" "this_github" {
  count  = var.source_github_name != "" && var.create_s3_bucket ? 1 : 0
  name   = "github-${var.name}-policy"
  policy = data.aws_iam_policy_document.this_github_s3[0].json
  role   = aws_iam_role.this_github[0].id
}

#attach lambda policy
resource "aws_iam_role_policy" "this_lambda" {
  name   = "lambda-${var.name}-policy"
  policy = data.aws_iam_policy_document.this_lambda.json
  role   = aws_iam_role.this_github[0].id
}

#allows users to attach additional IAM policies
resource "aws_iam_role_policy" "this_additional" {
  count  = length(coalesce(var.source_github_additional_iam_policies, [])) > 0 && var.source_github_name != "" ? length(coalesce(var.source_github_additional_iam_policies, [])) : 0
  name   = "github-${var.source_github_name}-policy-${count.index}"
  policy = var.source_github_additional_iam_policies[count.index]
  role   = aws_iam_role.this_github[0].id
}