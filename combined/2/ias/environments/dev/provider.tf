terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.65.0"
    }
  }

  required_version = ">= 1.8.5"

  backend "s3" {
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}