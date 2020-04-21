# ===================================================================
# Locals
# ===================================================================

locals {
    vault_storage_dyndb      = contains(var.vault_storage, "dynamodb")
    vault_storage_dyndb_name = join("", aws_dynamodb_table.vault_storage[*].name)
    vault_storage_dyndb_arn  = join("", aws_dynamodb_table.vault_storage[*].arn)
}

# ===================================================================
# Resources
# ===================================================================

# Create a DynamoDB table and scaling policies to store vault data
resource "aws_dynamodb_table" "vault_storage" {
    count = local.vault_storage_dyndb ? 1 : 0

    name         = "${var.project}-storage"
    billing_mode = "PAY_PER_REQUEST"

    hash_key  = "Path"
    range_key = "Key"

    attribute {
        name = "Path"
        type = "S"
    }

    attribute {
        name = "Key"
        type = "S"
    }

    server_side_encryption {
        enabled     = true
        kms_key_arn = aws_kms_key.vault.arn
    }

    point_in_time_recovery {
        enabled = true
    }

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
