terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket              = "secvault-tfstate-429502077676-eu-central-1"
    key                 = "juice-shop/terraform.tfstate"
    region              = "eu-central-1"
    allowed_account_ids = ["429502077676"]
    use_lockfile        = true
    encrypt             = true
  }
}

provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = ["429502077676"]
}
