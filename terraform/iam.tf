# ===================================================================
# Data
# ===================================================================

data "aws_iam_policy_document" "vault_key" {
    statement {
        sid = "key-default-1"

        effect  = "Allow"
        actions = [ "kms:*" ]
        principals {
            type        = "AWS"
            identifiers = [ "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" ]
        }
        resources = [ "*" ]
    }

    statement {
        sid = "key-logs"

        effect = "Allow"
        actions = [
            "kms:Encrypt*",
            "kms:Decrypt*",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:Describe*",
        ]
        principals {
            type        = "Service"
            identifiers = [ "logs.${data.aws_region.current.name}.amazonaws.com" ]
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
            type        = "AWS"
            identifiers = data.aws_iam_role.vault_key_user_role[*].arn
        }
        resources = [ "*" ]
    }
}

data "aws_iam_role" "vault_key_user_role" {
    count = length(var.vault_key_user_roles)

    name = var.vault_key_user_roles[count.index]
}

# ===================================================================
# Resources
# ===================================================================

resource "aws_kms_key" "vault" {
    description             = "Protects all vault secure information."
    deletion_window_in_days = lower(var.environment) == "production" ? 30 : 7

    policy = data.aws_iam_policy_document.vault_key.json

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }

    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_kms_alias" "vault" {
    name          = "alias/${var.project}"
    target_key_id = aws_kms_key.vault.id
}

resource "aws_secretsmanager_secret" "vault_master" {
    name        = "${var.project}/master"
    description = "Segmented master keys for unsealing vault."

    kms_key_id              = aws_kms_key.vault.id
    recovery_window_in_days = lower(var.environment) == "production" ? 30 : 7

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }

    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_secretsmanager_secret" "vault_recovery" {
    name        = "${var.project}/recovery"
    description = "Segmented recovery keys for unsealing vault."

    kms_key_id              = aws_kms_key.vault.id
    recovery_window_in_days = lower(var.environment) == "production" ? 30 : 7

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }

    lifecycle {
        prevent_destroy = true
    }
}
