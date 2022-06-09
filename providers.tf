terraform {
  required_version = "v0.14.8"

#   backend "s3" {
#     bucket  = "aws-s3.terraform-state"
#     key     = "tf-project.tfstate"
#     region  = "eu-west-2"
#     profile = "aws-test"
#   }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  profile = "aws-test"
  region  = "eu-west-2"
}