terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Step 2: once the first apply works, create an S3 bucket for state by hand
  # (or in a separate bootstrap config), then uncomment this block and run
  # `terraform init -migrate-state`.
  #
  # backend "s3" {
  #   bucket  = "YOUR-TFSTATE-BUCKET"
  #   key     = "secure-ai-sandbox/terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
