terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state by default so this is easy to run standalone for the
  # assignment. For real production use, switch to an S3 + DynamoDB remote
  # backend (see infrastructure/README.md) before applying.
  # backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}
