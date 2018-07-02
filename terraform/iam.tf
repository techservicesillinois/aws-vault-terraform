# ===================================================================
# Data
# ===================================================================

data "aws_iam_policy_document" "instance_logs" {
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
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
        ]
        resources = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/${var.project}/ec2-instances/*",
        ]
    }
}

data "aws_iam_policy_document" "vault_key" {
    statement {
        sid = "key-default-1"

        effect = "Allow"
        actions = [ "kms:*" ]
        principals {
            type = "AWS"
            identifiers = [ "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" ]
        }
        resources = [ "*" ]
    }

    statement {
        sid = "key-user-roles"

        effect = "Allow"
        actions = [
            "kms:Decrypt",
            "kms:Encrypt",
            "kms:DescribeKey",
            "kms:GenerateDataKey*",
            "kms:GenerateRandom",
        ]
        principals {
            type = "AWS"
            identifiers = [ "${data.aws_iam_role.vault_key_user_role.*.arn}" ]
        }
        resources = [ "*" ]
    }
}


data "aws_iam_role" "vault_key_user_role" {
    count = "${length(var.vault_key_user_roles)}"

    name = "${element(var.vault_key_user_roles, count.index)}"
}


# ===================================================================
# Resources
# ===================================================================

resource "aws_iam_policy" "instance_logs" {
    name_prefix = "${var.project}-instance-logs-"
    path = "/${var.project}/"
    description = "Allow ${var.project} instances to send logs to CloudWatch logs"

    policy = "${data.aws_iam_policy_document.instance_logs.json}"

    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_kms_key" "vault" {
    description = "Protects all vault secure information."
    deletion_window_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    policy = "${data.aws_iam_policy_document.vault_key.json}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        prevent_destroy = true
    }
}
resource "aws_kms_alias" "vault" {
    name = "alias/${var.project}"
    target_key_id = "${aws_kms_key.vault.id}"
}


resource "aws_secretsmanager_secret" "vault_master" {
    name = "${var.project}/master"
    description = "Segmented master keys for unsealing vault."

    kms_key_id = "${aws_kms_key.vault.id}"
    recovery_window_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        prevent_destroy = true
    }
}
