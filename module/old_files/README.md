<!-- BEGIN_TF_DOCS -->
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

The code above assumes you're creating the bucket in the same Terraform file. If it's not created in the same location, you can use a `data` block lookup for [aws\_s3\_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket). Keep in mind that by separating the location of the bucket from the code that manages the permissions can be mildly risky if not understood and tracked appropriately!

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.this_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.lambda_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.this_github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.additional_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.this_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.this_dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.this_github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.this_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.this_lambda_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_object.dotnet_lambda_code](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.java_lambda_code](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.nodejs_lambda_code](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.python_lambda_code](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [local_file.this_dotnet](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.this_java](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.this_nodejs](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.this_python](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [random_string.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [archive_file.this_dotnet](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.this_java](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.this_nodejs](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.this_python](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this_dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this_github_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this_github_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this_lambda_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this_lambda_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_iam_policies"></a> [additional\_iam\_policies](#input\_additional\_iam\_policies) | A list of additional JSON policy documents to attach to the Lambda execution role | `list(string)` | `[]` | no |
| <a name="input_application_log_level"></a> [application\_log\_level](#input\_application\_log\_level) | The logging level for application logs | `string` | `"INFO"` | no |
| <a name="input_concurrency_limit"></a> [concurrency\_limit](#input\_concurrency\_limit) | Lambda concurrency execution limit. (-1 for unreserved) | `number` | `-1` | no |
| <a name="input_create_s3_bucket"></a> [create\_s3\_bucket](#input\_create\_s3\_bucket) | Creates a dedicated S3 bucket for code storage | `bool` | `true` | no |
| <a name="input_dead_letter_arn"></a> [dead\_letter\_arn](#input\_dead\_letter\_arn) | String, ARN of the SNS topic or SQS queue to notify when invocation fails. | `string` | `""` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the Lambda | `string` | `""` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Environment variables for the lambda | `map(any)` | `{}` | no |
| <a name="input_ephemeral_storage_size"></a> [ephemeral\_storage\_size](#input\_ephemeral\_storage\_size) | Size allocated to the /tmp storage | `number` | `512` | no |
| <a name="input_folder_name"></a> [folder\_name](#input\_folder\_name) | Stores the code in provided folder name within the S3 bucket | `string` | `""` | no |
| <a name="input_lambda_code_s3_key"></a> [lambda\_code\_s3\_key](#input\_lambda\_code\_s3\_key) | S3 key for the Lambda function code | `string` | `"lambda_function"` | no |
| <a name="input_lambda_handler"></a> [lambda\_handler](#input\_lambda\_handler) | The handler for the Lambda function | `string` | `""` | no |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | The runtime environment for the Lambda function (e.g., python3.8, dotnetcore3.1, nodejs14.x, java11) | `string` | n/a | yes |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Number of days to retain logs | `number` | `7` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Amount of memory to allocate to the Lambda in MBs | `number` | `128` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the function and resources | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Uses a provided S3 bucket name for code storage | `string` | `""` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security Group IDs to attach to the lambda's execution | `list(string)` | n/a | yes |
| <a name="input_source_github_additional_iam_policies"></a> [source\_github\_additional\_iam\_policies](#input\_source\_github\_additional\_iam\_policies) | Additional IAM policy JSONs to add to the Github IAM role | `list(string)` | `[]` | no |
| <a name="input_source_github_name"></a> [source\_github\_name](#input\_source\_github\_name) | Name of the Github repository where the code comes from | `string` | `""` | no |
| <a name="input_source_github_organization"></a> [source\_github\_organization](#input\_source\_github\_organization) | Name of the Github organization where the code comes from | `string` | `"IntelexTechnologies"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the lambda's execution | `list(string)` | n/a | yes |
| <a name="input_system_log_level"></a> [system\_log\_level](#input\_system\_log\_level) | The logging level for system logs | `string` | `"WARN"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to the resources | `map(any)` | n/a | yes |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Timeout execution for the Lambda | `number` | `5` | no |
| <a name="input_tracing"></a> [tracing](#input\_tracing) | The tracing mode for the Lambda function | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_iam_role_arn"></a> [github\_iam\_role\_arn](#output\_github\_iam\_role\_arn) | ARN of the Github Actions IAM role, if created |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | String, ARN of the lambda function |
| <a name="output_lambda_function_invoke_arn"></a> [lambda\_function\_invoke\_arn](#output\_lambda\_function\_invoke\_arn) | String, ARN of the lambda function to invoke |
| <a name="output_lambda_iam_execution_role"></a> [lambda\_iam\_execution\_role](#output\_lambda\_iam\_execution\_role) | n/a |
| <a name="output_lambda_name"></a> [lambda\_name](#output\_lambda\_name) | String, Name of the lambda function |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | String, ARN of the S3 bucket if created |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | String, name of the S3 bucket if created |
<!-- END_TF_DOCS -->