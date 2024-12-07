terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.6.0" 
    }
  }

  required_version = ">= 1.8.5" 
}

# Provider for us-east-1 region
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

# Provider for us-west-2 region
provider "aws" {
  alias  = "us_west"
  region = "us-west-2"
}

