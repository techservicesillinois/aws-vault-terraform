# ===================================================================
# Data
# ===================================================================

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ami" "ecs_optimized2" {
    most_recent = true

    filter {
        name   = "name"
        values = [ "amzn2-ami-ecs-*-ebs" ]
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

data "aws_iam_policy" "AmazonEC2ContainerServiceforEC2Role" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy" "CloudWatchAgentServerPolicy" {
    arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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



locals {
    # Docker: map a host instance type to the main task's CPU reservation.
    # Calculated as 50% the number of CPU units available for the type.
    docker_instance2cpu_default = {
        "t3.micro"      = 1024
        "t3.small"      = 1024
        "t3.medium"     = 1024
        "t3.large"      = 1024
        "t3.xlarge"     = 2048
        "t3.2xlarge"    = 4096

        "t3a.micro"     = 1024
        "t3a.small"     = 1024
        "t3a.medium"    = 1024
        "t3a.large"     = 1024
        "t3a.xlarge"    = 2048
        "t3a.2xlarge"   = 4096

        "t2.micro"      = 512
        "t2.small"      = 512
        "t2.medium"     = 1024
        "t2.large"      = 1024
        "t2.xlarge"     = 2048
        "t2.2xlarge"    = 4096

        "m5.large"      = 1024
        "m5.xlarge"     = 2048
        "m5.2xlarge"    = 4096
        "m5.4xlarge"    = 8192
        "m5.8xlarge"    = 16384
        "m5.12xlarge"   = 24576
        "m5.16xlarge"   = 32768
        "m5.24xlarge"   = 49152
        "m5d.large"     = 1024
        "m5d.xlarge"    = 2048
        "m5d.2xlarge"   = 4096
        "m5d.4xlarge"   = 8192
        "m5d.8xlarge"   = 16384
        "m5d.12xlarge"  = 24576
        "m5d.16xlarge"  = 32768
        "m5d.24xlarge"  = 49152

        "m5a.large"     = 1024
        "m5a.xlarge"    = 2048
        "m5a.2xlarge"   = 4096
        "m5a.4xlarge"   = 8192
        "m5a.8xlarge"   = 16384
        "m5a.12xlarge"  = 24576
        "m5a.16xlarge"  = 32768
        "m5a.24xlarge"  = 49152
        "m5ad.large"    = 1024
        "m5ad.xlarge"   = 2048
        "m5ad.2xlarge"  = 4096
        "m5ad.4xlarge"  = 8192
        "m5ad.12xlarge" = 24576
        "m5ad.24xlarge" = 49152

        "m5n.large"     = 1024
        "m5n.xlarge"    = 2048
        "m5n.2xlarge"   = 4096
        "m5n.4xlarge"   = 8192
        "m5n.8xlarge"   = 16384
        "m5n.12xlarge"  = 24576
        "m5n.16xlarge"  = 32768
        "m5n.24xlarge"  = 49152
        "m5dn.large"    = 1024
        "m5dn.xlarge"   = 2048
        "m5dn.2xlarge"  = 4096
        "m5dn.4xlarge"  = 8192
        "m5dn.8xlarge"  = 16384
        "m5dn.12xlarge" = 24576
        "m5dn.16xlarge" = 32768
        "m5dn.24xlarge" = 49152

        "m4.large"      = 1024
        "m4.xlarge"     = 2048
        "m4.2xlarge"    = 4096
        "m4.4xlarge"    = 8192
        "m4.10xlarge"   = 20480
        "m4.16xlarge"   = 32768

        "c5.large"      = 1024
        "c5.xlarge"     = 2048
        "c5.2xlarge"    = 4096
        "c5.4xlarge"    = 8192
        "c5.9xlarge"    = 18432
        "c5.12xlarge"   = 24576
        "c5.18xlarge"   = 36864
        "c5.24xlarge"   = 49152
        "c5d.large"     = 1024
        "c5d.xlarge"    = 2048
        "c5d.2xlarge"   = 4096
        "c5d.4xlarge"   = 8192
        "c5d.9xlarge"   = 18432
        "c5d.12xlarge"  = 24576
        "c5d.18xlarge"  = 36864
        "c5d.24xlarge"  = 49152

        "c5n.large"     = 1024
        "c5n.xlarge"    = 2048
        "c5n.2xlarge"   = 4096
        "c5n.4xlarge"   = 8192
        "c5n.9xlarge"   = 18432
        "c5n.18xlarge"  = 36864

        "c4.large"      = 1024
        "c4.xlarge"     = 2048
        "c4.2xlarge"    = 4096
        "c4.4xlarge"    = 8192
        "c4.8xlarge"    = 18432

        "g4dn.xlarge"   = 2048
        "g4dn.2xlarge"  = 4096
        "g4dn.4xlarge"  = 8192
        "g4dn.8xlarge"  = 16384
        "g4dn.12xlarge" = 24576
        "g4dn.16xlarge" = 32768

        "g3s.xlarge"    = 2048
        "g3.4xlarge"    = 8192
        "g3.8xlarge"    = 16384
        "g3.16xlarge"   = 32768

        "p3.2xlarge"    = 4096
        "p3.8xlarge"    = 16384
        "p3.16xlarge"   = 32768
        "p3dn.24xlarge" = 49152

        "p2.xlarge"     = 2048
        "p2.8xlarge"    = 16384
        "p2.16xlarge"   = 32768

        "r5.large"      = 1024
        "r5.xlarge"     = 2048
        "r5.2xlarge"    = 4096
        "r5.4xlarge"    = 8192
        "r5.8xlarge"    = 16384
        "r5.12xlarge"   = 24576
        "r5.16xlarge"   = 32768
        "r5.24xlarge"   = 49152
        "r5d.large"     = 1024
        "r5d.xlarge"    = 2048
        "r5d.2xlarge"   = 4096
        "r5d.4xlarge"   = 8192
        "r5d.8xlarge"   = 16384
        "r5d.12xlarge"  = 24576
        "r5d.16xlarge"  = 32768
        "r5d.24xlarge"  = 49152

        "r5a.large"     = 1024
        "r5a.xlarge"    = 2048
        "r5a.2xlarge"   = 4096
        "r5a.4xlarge"   = 8192
        "r5a.8xlarge"   = 16384
        "r5a.12xlarge"  = 24576
        "r5a.16xlarge"  = 32768
        "r5a.24xlarge"  = 49152
        "r5ad.large"    = 1024
        "r5ad.xlarge"   = 2048
        "r5ad.2xlarge"  = 4096
        "r5ad.4xlarge"  = 8192
        "r5ad.12xlarge" = 24576
        "r5d.24xlarge"  = 49152

        "r5n.large"     = 1024
        "r5n.xlarge"    = 2048
        "r5n.2xlarge"   = 4096
        "r5n.4xlarge"   = 8192
        "r5n.8xlarge"   = 16384
        "r5n.12xlarge"  = 24576
        "r5n.16xlarge"  = 32768
        "r5n.24xlarge"  = 49152
        "r5dn.large"    = 1024
        "r5dn.xlarge"   = 2048
        "r5dn.2xlarge"  = 4096
        "r5dn.4xlarge"  = 8192
        "r5dn.8xlarge"  = 16384
        "r5dn.12xlarge" = 24576
        "r5dn.16xlarge" = 32768
        "r5dn.24xlarge" = 49152

        "r4.large"      = 1024
        "r4.xlarge"     = 2048
        "r4.2xlarge"    = 4096
        "r4.4xlarge"    = 8192
        "r4.8xlarge"    = 16384
        "r4.16xlarge"   = 32768

        "x1e.xlarge"    = 2048
        "x1e.2xlarge"   = 4096
        "x1e.4xlarge"   = 8192
        "x1e.8xlarge"   = 16384
        "x1e.16xlarge"  = 32768
        "x1e.32xlarge"  = 65536

        "x1.16xlarge"   = 32768
        "x1.32xlarge"   = 65536

        "z1d.large"     = 1024
        "z1d.xlarge"    = 2048
        "z1d.2xlarge"   = 4096
        "z1d.3xlarge"   = 6144
        "z1d.6xlarge"   = 12288
        "z1d.12xlarge"  = 24576
    }
    docker_instance2cpu = merge(local.docker_instance2cpu_default, var.docker_instance2cpu)

    # Docker: map the host instance type to the main task's RAM limit.
    # Calculated as the (Total RAM) - 512M.
    docker_instance2memory_default = {
        "t3.micro"      = 512
        "t3.small"      = 1536
        "t3.medium"     = 3584
        "t3.large"      = 7680
        "t3.xlarge"     = 15872
        "t3.2xlarge"    = 32256

        "t3a.micro"     = 512
        "t3a.small"     = 1536
        "t3a.medium"    = 3584
        "t3a.large"     = 7680
        "t3a.xlarge"    = 15872
        "t3a.2xlarge"   = 32256

        "t2.micro"      = 512
        "t2.small"      = 1536
        "t2.medium"     = 3584
        "t2.large"      = 7680
        "t2.xlarge"     = 15872
        "t2.2xlarge"    = 32256

        "m5.large"      = 7680
        "m5.xlarge"     = 15872
        "m5.2xlarge"    = 32256
        "m5.4xlarge"    = 65024
        "m5.8xlarge"    = 130560
        "m5.12xlarge"   = 196096
        "m5.16xlarge"   = 261632
        "m5.24xlarge"   = 392704
        "m5d.large"     = 7680
        "m5d.xlarge"    = 15872
        "m5d.2xlarge"   = 32256
        "m5d.4xlarge"   = 65024
        "m5d.8xlarge"   = 130560
        "m5d.12xlarge"  = 196096
        "m5d.16xlarge"  = 261632
        "m5d.24xlarge"  = 392704

        "m5a.large"     = 7680
        "m5a.xlarge"    = 15872
        "m5a.2xlarge"   = 32256
        "m5a.4xlarge"   = 65024
        "m5a.8xlarge"   = 130560
        "m5a.12xlarge"  = 196096
        "m5a.16xlarge"  = 261632
        "m5a.24xlarge"  = 392704
        "m5ad.large"    = 7680
        "m5ad.xlarge"   = 15872
        "m5ad.2xlarge"  = 32256
        "m5ad.4xlarge"  = 65024
        "m5ad.12xlarge" = 196096
        "m5ad.24xlarge" = 392704

        "m5n.large"     = 7680
        "m5n.xlarge"    = 15872
        "m5n.2xlarge"   = 32256
        "m5n.4xlarge"   = 65024
        "m5n.8xlarge"   = 130560
        "m5n.12xlarge"  = 196096
        "m5n.16xlarge"  = 261632
        "m5n.24xlarge"  = 392704
        "m5dn.large"    = 7680
        "m5dn.xlarge"   = 15872
        "m5dn.2xlarge"  = 32256
        "m5dn.4xlarge"  = 65024
        "m5dn.8xlarge"  = 130560
        "m5dn.12xlarge" = 196096
        "m5dn.16xlarge" = 261632
        "m5dn.24xlarge" = 392704

        "m4.large"      = 7680
        "m4.xlarge"     = 15872
        "m4.2xlarge"    = 32256
        "m4.4xlarge"    = 65024
        "m4.10xlarge"   = 163328
        "m4.16xlarge"   = 261632

        "c5.large"      = 3584
        "c5.xlarge"     = 7680
        "c5.2xlarge"    = 15872
        "c5.4xlarge"    = 32256
        "c5.9xlarge"    = 73216
        "c5.12xlarge"   = 97792
        "c5.18xlarge"   = 146944
        "c5.24xlarge"   = 196096
        "c5d.large"     = 3584
        "c5d.xlarge"    = 7680
        "c5d.2xlarge"   = 15872
        "c5d.4xlarge"   = 32256
        "c5d.9xlarge"   = 73216
        "c5d.12xlarge"  = 97792
        "c5d.18xlarge"  = 146944
        "c5d.24xlarge"  = 196096

        "c5n.large"     = 4864
        "c5n.xlarge"    = 10240
        "c5n.2xlarge"   = 20992
        "c5n.4xlarge"   = 42496
        "c5n.9xlarge"   = 97792
        "c5n.18xlarge"  = 196096

        "c4.large"      = 3328
        "c4.xlarge"     = 7168
        "c4.2xlarge"    = 14848
        "c4.4xlarge"    = 30208
        "c4.8xlarge"    = 60928

        "g4dn.xlarge"   = 15872
        "g4dn.2xlarge"  = 32256
        "g4dn.4xlarge"  = 65024
        "g4dn.8xlarge"  = 130560
        "g4dn.12xlarge" = 196096
        "g4dn.16xlarge" = 261632

        "g3s.xlarge"    = 30720
        "g3.4xlarge"    = 124416
        "g3.8xlarge"    = 249344
        "g3.16xlarge"   = 499200

        "p3.2xlarge"    = 61952
        "p3.8xlarge"    = 249344
        "p3.16xlarge"   = 499200

        "p2.xlarge"     = 61952
        "p2.8xlarge"    = 499200
        "p2.16xlarge"   = 749056

        "r5.large"      = 15872
        "r5.xlarge"     = 32256
        "r5.2xlarge"    = 65024
        "r5.4xlarge"    = 130560
        "r5.8xlarge"    = 261632
        "r5.12xlarge"   = 392704
        "r5.16xlarge"   = 523776
        "r5.24xlarge"   = 785920
        "r5d.large"     = 15872
        "r5d.xlarge"    = 32256
        "r5d.2xlarge"   = 65024
        "r5d.4xlarge"   = 130560
        "r5d.8xlarge"   = 261632
        "r5d.12xlarge"  = 392704
        "r5d.16xlarge"  = 523776
        "r5d.24xlarge"  = 785920

        "r5a.large"     = 15872
        "r5a.xlarge"    = 32256
        "r5a.2xlarge"   = 65024
        "r5a.4xlarge"   = 130560
        "r5a.8xlarge"   = 261632
        "r5a.12xlarge"  = 392704
        "r5a.16xlarge"  = 523776
        "r5a.24xlarge"  = 785920
        "r5ad.large"    = 15872
        "r5ad.xlarge"   = 32256
        "r5ad.2xlarge"  = 65024
        "r5ad.4xlarge"  = 130560
        "r5ad.12xlarge" = 392704
        "r5d.24xlarge"  = 785920

        "r5n.large"     = 15872
        "r5n.xlarge"    = 32256
        "r5n.2xlarge"   = 65024
        "r5n.4xlarge"   = 130560
        "r5n.8xlarge"   = 261632
        "r5n.12xlarge"  = 392704
        "r5n.16xlarge"  = 523776
        "r5n.24xlarge"  = 785920
        "r5dn.large"    = 15872
        "r5dn.xlarge"   = 32256
        "r5dn.2xlarge"  = 65024
        "r5dn.4xlarge"  = 130560
        "r5dn.8xlarge"  = 261632
        "r5dn.12xlarge" = 392704
        "r5dn.16xlarge" = 523776
        "r5dn.24xlarge" = 785920

        "r4.large"      = 15104
        "r4.xlarge"     = 30720
        "r4.2xlarge"    = 61952
        "r4.4xlarge"    = 124416
        "r4.8xlarge"    = 249344
        "r4.16xlarge"   = 499200

        "x1e.xlarge"    = 124416
        "x1e.2xlarge"   = 249344
        "x1e.4xlarge"   = 499200
        "x1e.8xlarge"   = 998912
        "x1e.16xlarge"  = 1998336
        "x1e.32xlarge"  = 3997184

        "x1.16xlarge"   = 998912
        "x1.32xlarge"   = 1998336

        "z1d.large"     = 15872
        "z1d.xlarge"    = 32256
        "z1d.2xlarge"   = 65024
        "z1d.3xlarge"   = 97792
        "z1d.6xlarge"   = 196096
        "z1d.12xlarge"  = 392704
    }
    docker_instance2memory = merge(local.docker_instance2memory_default, var.docker_instance2memory)
}