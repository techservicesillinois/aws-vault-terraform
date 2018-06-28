terraform {
    required_version = "~> 0.11.7"

    backend "s3" {
        bucket = "uiuc-sbutler1-sandbox"
        key = "vault/terraform/state"
        dynamodb_table = "terraform"

        encrypt = true

        region = "us-east-2"
    }
}


provider "aws" {
    version = "~> 1.25"

    region = "us-east-2"
}
provider "aws" {
    alias = "us_east_1"

    region = "us-east-1"
}
