# AWS-Lambda

This is the Terraform Module for using Intelex Standard AWS Lambda

## Working Example

In order to utilize this Terraform Module, you can copy and paste the code below and fill your values where appropriate:

```
module "my_lambda_function" {
  source              = "git::https://github.com/IntelexTechnologies/aws-lambda?ref=<CHECK-THE-LATEST-RELEASE-NUMBER>"
  name                = "my-sample-lambda-function"
  subnet_ids          = [ "subnet-id-1", "subnet-id-2"]
  security_group_ids  = [ "security-group-id-1" ]
  lambda_runtime      = "python3.9" # Change this to the desired runtime (e.g., python3.8, dotnetcore3.1, nodejs14.x, java11)
  lambda_code_s3_key  = "lambda_function" # The key (file name) in the S3 bucket for the lambda to read from
  tags = {
        "MySecretEnvironment":"MyEnvironment" #You should look at the Generic Tags Module
    }
}
```

## What is an AWS Lambda?

AWS Lambda is a serverless technology for executing code. Lambdas are _amazing_ and should be utilized whenever possible! There is so much that you can say about Lambda, it's best just to read from the [beginning](https://aws.amazon.com/lambda/). 

## Module Features

- Because a lambda cannot be created without baseline code, on instantiation of this module, a default block of code is uploaded into the S3 bucket for the created Lambda to read.

- The default IAM role permits it read from the S3 bucket that is created, as well as providing metrics to Cloudwatch.

- If you provide an ARN of an SNS or SQS for dead letter queue messages, the IAM permission to send is automatically added to the Lambda.

## Important Notes

- Uploading a new file to the S3 bucket does not trigger a new build of the Lambda--you must do this via your deployment pipeline.

- We require the `subnet_ids` to force the Lambdas to exist inside the VPC. This makes networking and connectivity in general so much easier. And because of this, the `security_group_ids` are also required.

## Terraform Behaviors

**This is extremely important:**

Because the Lambda requires a source code upload for it's initial instantiation, _every time it executes_ it will read from a `data "archive_file" "this_..."` and create a corresponding `resource "local_file" "this_..."`. I literally can't do anything about this at this time. It won't upload it after the first initial upload, so don't worry! 

## Interacting with Github Actions

This repository also enables you to have an IAM role automatically created that will work with Github Actions that can be assumed in your actions workflow definition. By populating the `source_github_name` with the relevant Github repository, an IAM role will be created for you!

```
module "my_lambda_function" {
  source              = "git::https://github.com/IntelexTechnologies/aws-lambda?ref=<CHECK-THE-LATEST-RELEASE-NUMBER>"
  name                = "my-sample-lambda-function"
  [...]
  source_github_name  = "my-github-repository"
  tags = {
        "MySecretEnvironment":"MyEnvironment" #You should look at the Generic Tags Module
    }
}

output "function_name" {
  value = module.my_lambda_function.lambda_name
}

output "bucket" {
  value = module.my_lambda_function.s3_bucket_name
}

output "github_role" {
  value = module.my_lambda_function.github_iam_role_arn
}
```

- The `source_github_name` is simply the name of the repository in Github--just the repository, no Organization, and no branches.

You'll need the output to get the ARN of the Github Actions role that was created.

If you want to use that Github Action for interacting with additional resources, you can create IAM policy text and attach it by providing the JSON under the `source_github_additional_iam_policies` piece and it'll attach them:

```
data "aws_iam_policy_document" "my_other_policy" {
  statement {
    effect = "Allow"

    actions = [
      "<...>"
    ]

    resources = [
      "<...>"
    ]
  }
}

module "my_lambda_function" {
  source              = "git::https://github.com/IntelexTechnologies/aws-lambda?ref=<CHECK-THE-LATEST-RELEASE-NUMBER>"
  [...]
  source_github_name  = "my-github-repository"
  source_github_additional_iam_policies = [
    data.aws_iam_policy_document.my_other_policy.json
  ]
  tags = {
        "MySecretEnvironment":"MyEnvironment" #You should look at the Generic Tags Module
    }
}

output "function_name" {
  value = module.my_lambda_function.lambda_name
}

output "bucket" {
  value = module.my_lambda_function.s3_bucket_name
}

output "github_role" {
  value = module.my_lambda_function.github_iam_role_arn
}
```

### Github Actions Workflow

You can set your Github Actions Pipeline to utilize this IAM role by having these key components in your `.yml` file:

```yml
name: Upload Package to AWS Lambda

on:
  push:
    branches:
      - main  # Trigger on pushes to the main branch

permissions:
  id-token: write  # This is required for requesting the JWT
  contents: read   # This is required for actions/checkout

jobs:
  i_use_aws:
    runs-on: ubuntu-latest #change it to what you need

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Configure AWS credentials using OIDC
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: "<my-assumed-iam-role>"
        aws-region: "<your-deployed-region>"

    - name: Install AWS CLI
      run: sudo apt-get install -y -q awscli

    - name: Zip your files
      run: |
        zip -r <s3-key-value>.zip . -i '*.<extension>'

    - name: Upload to S3
      run: |
        aws s3 cp <s3-key-value>.zip s3://<the-bucket-name>/

    - name: Update Lambda
      run: |
        aws lambda update-function-code --function-name <your-function-name> --s3-bucket <your-bucket-name> --s3-key <s3-key-value>.zip

```

Having this little block will allow you to use the newly created Github role with your Github Actions pipeline, upload the file(s) to the S3 bucket, and trigger a re-deploy of the function.

## Using an existing S3 bucket

Instead of having the module create the S3 bucket, you can instead opt to provide an existing S3 bucket for it's use, however you'll need to provide the IAM role access to the S3 bucket for the lambda to read the bucket for it's source code, and if you utilize the Github Action, the assumed IAM role. This is what that code can look like:

```
module "my_bucket" {
    source          = "git::https://github.com/IntelexTechnologies/aws-s3?ref=<CHECK-THE-LATEST-RELEASE-NUMBER>"
    bucket_name     = "<the-bucket-name>"
    tags            = {
        "MySecretEnvironment":"MyEnvironment" #You should look at the Generic Tags Module
    }
}

resource "aws_s3_bucket_policy" "this" {
    bucket = module.my_bucket.bucket_id
    policy = data.aws_iam_policy_document.s3_access_policy.json
}

data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    sid       = "AllowS3BucketActions"
    effect    = "Allow"
    actions   = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${module.my_bucket.bucket_name}",             # Bucket-level actions
      "arn:aws:s3:::${module.my_bucket.bucket_name}/*"           # Object-level actions
    ]
    principals {
      type        = "AWS"
      identifiers = [
        module.my_lambda_function.github_iam_role_arn,
        module.my_lambda_function.lambda_iam_execution_role
       ]
    }
  }
}

module "my_lambda_function" {
  source             = "git::https://github.com/IntelexTechnologies/aws-lambda?ref=<CHECK-THE-LATEST-RELEASE-NUMBER>"
  name               = "<your-lambda-name>"
  subnet_ids         = [ "<subnet-id-1>" ]
  security_group_ids = [ "<your-security-group-id>" ]
  lambda_runtime     = "dotnet8"          # Change this to the desired runtime (e.g., python3.8, dotnetcore3.1, nodejs14.x, java11)
  lambda_code_s3_key = "lambda_function"  # The key (file name) in the S3 bucket for the lambda to read from
  source_github_name = "<your-source-github-repo>"
  create_s3_bucket   = false
  s3_bucket_name     = module.my_bucket.bucket_name
  tags = {
    "MySecretEnvironment" : "MyEnvironment" #You should look at the Generic Tags Module
  }
}
```

By using the outputs of the bucket as inputs, Terraform is able to graph the map accordingly to create the appropriate resources in the appropriate order.

The code above assumes you're creating the bucket in the same Terraform file. If it's not created in the same location, you can use a `data` block lookup for [aws_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket). Keep in mind that by separating the location of the bucket from the code that manages the permissions can be mildly risky if not understood and tracked appropriately!