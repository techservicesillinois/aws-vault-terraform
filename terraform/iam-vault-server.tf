# =========================================================
# Data
# =========================================================

data "aws_iam_policy_document" "vault_server_instance" {
    statement {
        effect = "Allow"
        actions = [
            "logs:DescribeLogStreams",
        ]
        resources = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*",
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
        ]
        resources = [
            aws_cloudwatch_log_group.vault_server_containers.arn,
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "s3:GetObject*",
        ]
        resources = [
            "arn:aws:s3:::${var.deploy_bucket}/${var.deploy_prefix}*",
        ]
    }
}

data "aws_iam_policy_document" "vault_init_task" {
    statement {
        effect = "Allow"
        actions = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey*",
        ]
        resources = [
            aws_kms_key.vault.arn,
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "s3:GetObject*",
        ]
        resources = [
            "arn:aws:s3:::${var.deploy_bucket}/${var.deploy_prefix}ldap-credentials.txt",
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:ListSecretVersionIds",
            "secretsmanager:PutSecretValue",
            "secretsmanager:UpdateSecret",
            "secretsmanager:UpdateSecretVersionStage",
        ]
        resources = [
            aws_secretsmanager_secret.vault_master.arn,
            aws_secretsmanager_secret.vault_recovery.arn,
        ]
    }
}

data "aws_iam_policy_document" "vault_server_task" {
    statement {
        effect = "Allow"
        actions = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey*",
        ]
        resources = [
            aws_kms_key.vault.arn,
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "ec2:DescribeInstances",
            "iam:GetInstanceProfile",
            "iam:GetUser",
            "iam:GetRole",
        ]
        resources = ["*"]
    }
}

data "aws_iam_policy_document" "vault_server_dyndb_task" {
    statement {
        effect = "Allow"
        actions = [
            "dynamodb:*",
        ]
        resources = [
            local.vault_storage_dyndb_arn,
        ]
    }
}

# =========================================================
# Resources
# =========================================================

resource "aws_iam_policy" "vault_server_instance" {
    name_prefix = "${var.project}-ec2-"
    path        = "/${var.project}/"
    description = "Allow ${var.project} instances to read from the deployment bucket and send Docker vault-server container logs to CloudWatch Logs"

    policy = data.aws_iam_policy_document.vault_server_instance.json

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_policy" "vault_init_task" {
    name_prefix = "${var.project}-task-"
    path        = "/${var.project}/"
    description = "Allow ${var.project} vault server init task read and update the master and recovery Secrets"

    policy = data.aws_iam_policy_document.vault_init_task.json

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_policy" "vault_server_task" {
    name_prefix = "${var.project}-task-"
    path        = "/${var.project}/"
    description = "Allow ${var.project} vault server tasks to access the KMS and EC2 information"

    policy = data.aws_iam_policy_document.vault_server_task.json

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_policy" "vault_server_dyndb_task" {
    name_prefix = "${var.project}-task-"
    path        = "/${var.project}/"
    description = "Allow ${var.project} vault server tasks to access DynamoDB"

    policy = data.aws_iam_policy_document.vault_server_dyndb_task.json

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_instance_profile" "vault_server" {
    name_prefix = "${var.project}-server-"
    path        = "/${var.project}/server/"
    role        = aws_iam_role.vault_server.name
}

resource "aws_iam_role" "vault_server" {
    name_prefix = "${var.project}-server-"
    path        = "/${var.project}/server/"
    description = "ECS ${var.project} server instance role"

    assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_server_AmazonEC2ContainerServiceforEC2Role" {
    role       = aws_iam_role.vault_server.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_role_policy_attachment" "vault_server_instance_logs" {
    role       = aws_iam_role.vault_server.name
    policy_arn = aws_iam_policy.instance_logs.arn

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_role_policy_attachment" "vault_server_instance" {
    role       = aws_iam_role.vault_server.name
    policy_arn = aws_iam_policy.vault_server_instance.arn

    lifecycle {
        create_before_destroy = true
    }
}

# It can take a bit for policies to attached. Depend on this role to make sure
# all policies are attached and available.
resource "null_resource" "wait_vault_server_role" {
    depends_on = [
        aws_iam_role_policy_attachment.vault_server_AmazonEC2ContainerServiceforEC2Role,
        aws_iam_role_policy_attachment.vault_server_instance_logs,
        aws_iam_role_policy_attachment.vault_server_instance,
    ]

    provisioner "local-exec" {
        command = "sleep 30"
    }
}

resource "aws_iam_role" "vault_init_task" {
    name_prefix = "${var.project}-task-"
    path        = "/${var.project}/task/"
    description = "ECS ${var.project} vault-server init task role"

    assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_init_task" {
    role       = aws_iam_role.vault_init_task.name
    policy_arn = aws_iam_policy.vault_init_task.arn

    lifecycle {
        create_before_destroy = true
    }
}

# It can take a bit for policies to attached. Depend on this role to make sure
# all policies are attached and available.
resource "null_resource" "wait_vault_init_task_role" {
    depends_on = [ aws_iam_role_policy_attachment.vault_init_task ]

    provisioner "local-exec" {
        command = "sleep 30"
    }
}

resource "aws_iam_role" "vault_server_task" {
    name_prefix = "${var.project}-task-"
    path        = "/${var.project}/task/"
    description = "ECS ${var.project} vault-server task role"

    assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_server_task" {
    role       = aws_iam_role.vault_server_task.name
    policy_arn = aws_iam_policy.vault_server_task.arn

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_role_policy_attachment" "vault_server_dyndb_task" {
    count = local.vault_storage_dyndb ? 1 : 0

    role       = aws_iam_role.vault_server_task.name
    policy_arn = aws_iam_policy.vault_server_dyndb_task.arn

    lifecycle {
        create_before_destroy = true
    }
}

# It can take a bit for policies to attached. Depend on this role to make sure
# all policies are attached and available.
resource "null_resource" "wait_vault_server_task_role" {
    depends_on = [
        aws_iam_role_policy_attachment.vault_server_task,
        aws_iam_role_policy_attachment.vault_server_dyndb_task,
    ]

    provisioner "local-exec" {
        command = "sleep 30"
    }
}
