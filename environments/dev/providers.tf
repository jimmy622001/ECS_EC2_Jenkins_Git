provider "aws" {
  region = var.aws_region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0.0"

  # Comment out if you don't have the S3 bucket set up yet
  # backend "s3" {
  #   bucket         = "terraform-state-ecs-jenkins-github-dev"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks-ecs-jenkins-github-dev"
  # }
}