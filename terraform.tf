terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket         = "state-web-server-utxzao4f70w63039"
    encrypt        = true
    region         = "us-east-2"
    key            = "terraform.tfstate"
    dynamodb_table = "s3_state_locking"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}
