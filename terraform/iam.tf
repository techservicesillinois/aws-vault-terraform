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
