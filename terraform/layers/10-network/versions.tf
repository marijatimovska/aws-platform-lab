terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # bucket/key/region injected by scripts/tf.sh or CI:
  #   key = env/<env>/network.tfstate
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
      Layer       = "network"
      ManagedBy   = "terraform"
    }
  }
}
