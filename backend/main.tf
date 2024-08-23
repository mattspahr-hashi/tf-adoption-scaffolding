terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}

provider "random" {}

resource "random_string" "bucket_postfix" {
  special = false
  length  = 16
  upper   = false
}

# S3 Bucket for State
resource "aws_s3_bucket" "s3_bucket_state" {
  bucket = "state-web-server-${random_string.bucket_postfix.result}"
}

# Enable SSE
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encryption" {
  bucket = aws_s3_bucket.s3_bucket_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_user.iam_user.arn
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        Resource = [
          "${aws_s3_bucket.s3_bucket_state.arn}/*",
          aws_s3_bucket.s3_bucket_state.arn
        ]
      }
    ]
  })
}


# Enable Versioning
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.s3_bucket_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Table to lock state
resource "aws_dynamodb_table" "state_locking_table" {
  name           = "s3_state_locking"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

# IAM User for deployment
resource "aws_iam_user" "iam_user" {
  name = "backend-deployment"
  path = "/"
}

# IAM User Policy for deployment
resource "aws_iam_user_policy" "attach_s3_list_policy" {
  name = "backend-user-policy"
  user = aws_iam_user.iam_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = aws_s3_bucket.s3_bucket_state.arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "${aws_s3_bucket.s3_bucket_state.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Resource = aws_dynamodb_table.state_locking_table.arn
      }
    ]
  })
}
