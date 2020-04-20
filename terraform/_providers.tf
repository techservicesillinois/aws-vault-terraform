terraform {
    required_version = "~> 0.12.23"
    required_providers {
        aws = "~> 2.58.0"
    }

    backend "s3" {
        bucket         = "deploy-vault.example.illinois.edu-us-east-2"
        key            = "terraform/state"
        dynamodb_table = "terraform"

        encrypt = true

        region = "us-east-2"
    }
}

provider "aws" {
    region = "us-east-2"
}

provider "aws" {
    alias = "us_east_1"

    region = "us-east-1"
}
