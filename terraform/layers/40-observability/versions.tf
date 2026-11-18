terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # key = env/<env>/observability.tfstate
  backend "s3" {
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Layer       = "observability"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
