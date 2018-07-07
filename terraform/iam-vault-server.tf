# =========================================================
# Data
# =========================================================

data "aws_iam_policy_document" "vault_server_containers_logs" {
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
            "${aws_cloudwatch_log_group.vault_server_containers.arn}",
        ]
    }
}

data "aws_iam_policy_document" "vault_init_task" {
    statement {
        effect = "Allow",
        actions = [
            "kms:Decrypt",
            "kms:Encrypt",
            "kms:GenerateDataKey*",
        ]
        resources = [
            "${aws_kms_key.vault.arn}",
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:ListSecretVersionIds",
        ]
        resources = [
            "${data.aws_secretsmanager_secret.ldap_query.arn}",
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
            "secretsmanager:UpdateSecretVersionStage"
        ]
        resources = [
            "${aws_secretsmanager_secret.vault_master.arn}",
        ]
    }
}

data "aws_iam_policy_document" "vault_server_task" {
    statement {
        effect = "Allow"
        actions = [
            "ec2:DescribeInstances",
            "iam:GetInstanceProfile",
            "iam:GetUser",
            "iam:GetRole",
        ]
        resources = [ "*" ]
    }

    statement {
        effect = "Allow"
        actions = [
            "dynamodb:*",
        ]
        resources = [
            "${aws_dynamodb_table.vault_storage.arn}",
        ]
    }

    statement {
        effect = "Allow",
        actions = [
            "kms:Decrypt",
        ]
        resources = [
            "${aws_kms_key.vault.arn}",
        ]
    }

    statement {
        effect = "Allow"
        actions = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:ListSecretVersionIds",
        ]
        resources = [
            "${aws_secretsmanager_secret.vault_master.arn}",
        ]
    }
}


# =========================================================
# Resources
# =========================================================

resource "aws_iam_policy" "vault_server_containers_logs" {
    name_prefix = "${var.project}-logs-"
    path = "/${var.project}/"
    description = "Allow ${var.project} instances to send Docker vault-server container logs to CloudWatch Logs"

    policy = "${data.aws_iam_policy_document.vault_server_containers_logs.json}"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_policy" "vault_init_task" {
    name_prefix = "${var.project}-task-"
    path = "/${var.project}/"
    description = "Allow ${var.project} vault server init task read and update the master Secret"

    policy = "${data.aws_iam_policy_document.vault_init_task.json}"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_iam_policy" "vault_server_task" {
    name_prefix = "${var.project}-task-"
    path = "/${var.project}/"
    description = "Allow ${var.project} vault server tasks to access DynamoDB and the master Secret"

    policy = "${data.aws_iam_policy_document.vault_server_task.json}"

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_iam_instance_profile" "vault_server" {
    name_prefix = "${var.project}-server-"
    path = "/${var.project}/server/"
    role = "${aws_iam_role.vault_server.name}"
}

resource "aws_iam_role" "vault_server" {
    name_prefix = "${var.project}-server-"
    path = "/${var.project}/server/"
    description = "ECS ${var.project} server instance role"

    assume_role_policy = "${data.aws_iam_policy_document.instance_assume_role.json}"
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_server_AmazonEC2ContainerServiceforEC2Role" {
    role = "${aws_iam_role.vault_server.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_iam_role_policy_attachment" "vault_server_instance_logs" {
    role = "${aws_iam_role.vault_server.name}"
    policy_arn = "${aws_iam_policy.instance_logs.arn}"

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_iam_role_policy_attachment" "vault_server_containers_logs" {
    role = "${aws_iam_role.vault_server.name}"
    policy_arn = "${aws_iam_policy.vault_server_containers_logs.arn}"

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_iam_role" "vault_init_task" {
    name_prefix = "${var.project}-task-"
    path = "/${var.project}/task/"
    description = "ECS ${var.project} vault-server init task role"

    assume_role_policy = "${data.aws_iam_policy_document.task_assume_role.json}"
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_init_task" {
    role = "${aws_iam_role.vault_init_task.name}"
    policy_arn = "${aws_iam_policy.vault_init_task.arn}"

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_iam_role" "vault_server_task" {
    name_prefix = "${var.project}-task-"
    path = "/${var.project}/task/"
    description = "ECS ${var.project} vault-server task role"

    assume_role_policy = "${data.aws_iam_policy_document.task_assume_role.json}"
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_server_task" {
    role = "${aws_iam_role.vault_server_task.name}"
    policy_arn = "${aws_iam_policy.vault_server_task.arn}"

    lifecycle {
        create_before_destroy = true
    }
}
