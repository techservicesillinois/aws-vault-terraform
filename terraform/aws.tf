# ===================================================================
# Data
# ===================================================================

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ami" "ecs_optimized" {
    most_recent = true

    filter {
        name   = "name"
        values = [ "amzn-ami-*-amazon-ecs-optimized" ]
    }
    filter {
        name   = "virtualization-type"
        values = [ "hvm" ]
    }
    filter {
        name   = "architecture"
        values = [ "x86_64" ]
    }

    owners = [ "amazon" ]
}

data "aws_iam_policy_document" "instance_assume_role" {
    statement {
        effect  = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
            identifiers = [ "ec2.amazonaws.com" ]
        }
    }
}

data "aws_iam_policy_document" "task_assume_role" {
    statement {
        effect  = "Allow"
        actions = [ "sts:AssumeRole" ]
        principals {
            type        = "Service"
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

# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.OS.html
data "aws_iam_role" "rds_monitoring" {
    name = "rds-monitoring-role"
}
