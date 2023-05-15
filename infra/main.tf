terraform {
  required_providers {
    aws = {
      version = ">= 4.0.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

# two lambda functions w/ function url
# one dynamodb table
# roles and policies as needed
# step functions (if you're going for the bonus marks)

// CREATE OBITUARY

# create a role for the Lambda function to assume
# every service on AWS that wants to call other AWS services should first assume a role and
# then any policy attached to the role will give permissions
# to the service so it can interact with other AWS services
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "lambda" {
  name               = "iam-for-lambda-create-obituary-30141172"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# create archive file from main.py
data "archive_file" "create-obituary-archive" {
  type = "zip"
  # this file (main.py) needs to exist in the same folder as this 
  # Terraform configuration file
  source_dir = "../functions/create-obituary"
  output_path = "create-obituary.zip"
}

# create a Lambda function
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
resource "aws_lambda_function" "lambda" {
  role             = aws_iam_role.lambda.arn
  function_name    = "create-obituary-30141172"
  handler          = "main.lambda_handler"
  filename         = "create-obituary.zip"
  source_code_hash = data.archive_file.create-obituary-archive.output_base64sha256
  timeout = 20

  # see all available runtimes here: https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#SSS-CreateFunction-request-Runtime
  runtime = "python3.9"
}

# create a policy for publishing logs to CloudWatch
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "logs" {
  name        = "lambda-logging-create-obituary-30141172"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "dynamodb:*",
        "ssm:Describe*",
        "ssm:Get*",
        "ssm:List*"
      ],
      "Resource": ["arn:aws:logs:*:*:*","${aws_dynamodb_table.the-last-show-30142625.arn}"],
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ssm" {
  name        = "lambda-ssm-create-obituary-30141172"
  description = "IAM policy for ssm"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
            "Effect": "Allow",
            "Action": [
                "ssm:Describe*",
                "ssm:Get*",
                "ssm:List*"
            ],
            "Resource": "*"
        }
  ]
}
EOF
}

resource "aws_iam_policy" "polly" {
  name        = "lambda-polly-create-obituary-30141172"
  description = "IAM policy for polly"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "polly:DescribeVoices",
                "polly:GetLexicon",
                "polly:GetSpeechSynthesisTask",
                "polly:ListLexicons",
                "polly:ListSpeechSynthesisTasks",
                "polly:SynthesizeSpeech"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# attach the above policy to the function role
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.logs.arn
}

# attach the above policy to the function role
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "lambda_ssm" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.ssm.arn
}

# attach the above policy to the function role
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "lambda_polly" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.polly.arn
}

# create a Function URL for Lambda 
# see the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url
resource "aws_lambda_function_url" "url" {
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

# show the Function URL after creation
output "lambda_url" {
  value = aws_lambda_function_url.url.function_url
}


# read the docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
resource "aws_dynamodb_table" "the-last-show-30142625" {
  name         = "the-last-show-30142625"
  billing_mode = "PROVISIONED"

  # up to 8KB read per second (eventually consistent)
  read_capacity = 1

  # up to 1KB per second
  write_capacity = 1

  # we only need a student id to find an item in the table; therefore, we 
  # don't need a sort key here
  
  hash_key = "name" // CHANGE THESE  

  # the hash_key data type is string

  attribute {
    name = "name"
    type = "S"
  }
}

/***************************************************************************************************/
// GET OBITUARIES
# create a role for the Lambda function to assume

resource "aws_iam_role" "lambda_get_obituaries" {
  name               = "iam-for-lambda-get-obituaries"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# create archive file from delete_note.py
data "archive_file" "get-obituaries-30141172-archive" {
  type = "zip"
  source_dir = "../functions/get-obituaries"
  output_path = "get-obituaries.zip"
}

# create a Lambda function for deleting a note
resource "aws_lambda_function" "lambda_get_obituaries" {
  role             = aws_iam_role.lambda_get_obituaries.arn
  function_name    = "get-obituaries-30141172"
  handler          = "main.lambda_handler"
  filename         = "get-obituaries.zip"
  source_code_hash = data.archive_file.get-obituaries-30141172-archive.output_base64sha256
  timeout = 20
  runtime          = "python3.9"
}

# create a policy for deleting notes from the DynamoDB table
resource "aws_iam_policy" "dynamodb_get_obituaries_policy" {
  name = "dynamodb-get-obituraies-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "dynamodb:Scan"
        Effect = "Allow"
        Resource = aws_dynamodb_table.the-last-show-30142625.arn
      },
      {
        Action = ["logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# attach the above policy to the function role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_get_obituaries_policy" {
  policy_arn = aws_iam_policy.dynamodb_get_obituaries_policy.arn
  role       = aws_iam_role.lambda_get_obituaries.name
}

# create a Function URL for Lambda 
resource "aws_lambda_function_url" "get_obituaries_url" {
  function_name      = aws_lambda_function.lambda_get_obituaries.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

# show the Function URL after creation
output "get_obituaries_url" {
  value = aws_lambda_function_url.get_obituaries_url.function_url
}