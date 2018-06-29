# ===================================================================
# Data
# ===================================================================

data "aws_ami" "ecs_optimized" {
    most_recent = true
    filter {
        name = "name"
        values = [ "amzn-ami-*-amazon-ecs-optimized" ]
    }
    filter {
        name = "virtualization-type"
        values = [ "hvm" ]
    }
    filter {
        name = "architecture"
        values = [ "x86_64" ]
    }
    owners = [ "amazon" ]
}


data "aws_caller_identity" "current" {}


data "aws_iam_policy_document" "instance_assume_role" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type = "Service"
            identifiers = [ "ec2.amazonaws.com" ]
        }
    }
}


data "aws_iam_role" "appautoscaling_dynamodb" {
    name = "AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
}


data "aws_region" "current" {}
