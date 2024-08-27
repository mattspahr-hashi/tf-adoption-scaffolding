# DynamoDB Table for Logging
resource "aws_dynamodb_table" "logging_table" {
  name           = "terraform_audit_table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  range_key      = "info"

  attribute {
    name = "LockID"
    type = "S"
  }

  attribute {
    name = "info"
    type = "S"
  }
}

# Lambda Execution Role 
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda Execution Role Attachment
resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Write to Dynamo Policy
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "Policy to allow Lambda function to write to DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:BatchWriteItem",
        ],
        Resource = aws_dynamodb_table.logging_table.arn
      }
    ]
  })
}

# Write to Dynamo Policy Attachment
resource "aws_iam_policy_attachment" "lambda_dynamo_attachment" {
  name       = "lambda_dynamo_attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Read Dynamo Events Policy
resource "aws_iam_policy" "lambda_dynamodb_state_policy" {
  name        = "lambda_dynamodb_state_policy"
  description = "Policy to allow Lambda function to write to DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.state_locking_table.stream_arn
      }
    ]
  })
}

# Read Dynamo Events Policy Attachment
resource "aws_iam_policy_attachment" "lambda_dynamodb_state_policy_attachment" {
  name       = "lambda_dynamodb_state_policy"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_state_policy.arn
}

# Event Stream Dynamo -> Lambda
resource "aws_lambda_event_source_mapping" "log_event_source_mapping" {
  event_source_arn  = aws_dynamodb_table.state_locking_table.stream_arn
  function_name     = aws_lambda_function.logging-func.function_name
  starting_position = "LATEST"
  batch_size        = 1
}

# S3 Bucket Code
resource "aws_s3_bucket" "lambda-code" {
  bucket = "audit-lambda-code-bucket-${random_string.bucket_postfix.result}"
}

# Lambda Logging Function
resource "aws_lambda_function" "logging-func" {
  s3_bucket     = aws_s3_bucket.lambda-code.id
  s3_key        = "logging-lambda.zip"
  function_name = "audit_logging_function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
}
