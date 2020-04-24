# =========================================================
# Data
# =========================================================

data "aws_iam_policy_document" "sns_admin" {
    statement {
        sid    = "__default_statement_ID"
        effect = "Allow"
        actions = [
            "SNS:GetTopicAttributes",
            "SNS:SetTopicAttributes",
            "SNS:AddPermission",
            "SNS:RemovePermission",
            "SNS:DeleteTopic",
            "SNS:Subscribe",
            "SNS:ListSubscriptionsByTopic",
            "SNS:Publish",
            "SNS:Receive",
        ]
        resources = [ aws_sns_topic.admin.arn ]

        principals {
            type        = "AWS"
            identifiers = [ "*" ]
        }
        condition {
            test     = "StringEquals"
            variable = "AWS:SourceOwner"
            values   = [ data.aws_caller_identity.current.account_id ]
        }
    }
}

# ===================================================================
# Resources
# ===================================================================

# Single topic for all admin level notifications
resource "aws_sns_topic" "admin" {
    name = "${var.project}-admin-notifications"

    kms_master_key_id = aws_kms_key.vault.id

    provisioner "local-exec" {
        command = "aws sns subscribe --topic-arn '${self.arn}' --protocol email --notification-endpoint '${var.contact}'"
    }
}

resource "aws_sns_topic_policy" "admin" {
    arn    = aws_sns_topic.admin.arn
    policy = data.aws_iam_policy_document.sns_admin.json
}

