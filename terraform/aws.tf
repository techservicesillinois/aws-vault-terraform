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

data "aws_iam_policy_document" "task_assume_role" {
    statement {
        effect = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type = "Service"
            identifiers = [ "ecs-tasks.amazonaws.com" ]
        }
    }
}


data "aws_iam_role" "appautoscaling_dynamodb" {
    name = "AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
data "aws_iam_role" "task_execution" {
    name = "ecsTaskExecutionRole"
}


data "aws_region" "current" {}


data "aws_secretsmanager_secret" "ldap_query" {
    name = "${var.ldap_query_secret}"
}
data "aws_secretsmanager_secret_version" "ldap_query" {
    secret_id = "${data.aws_secretsmanager_secret.ldap_query.arn}"
}
