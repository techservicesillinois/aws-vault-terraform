# ===================================================================
# Locals
# ===================================================================

locals {
    vault_storage_dyndb_name = "${var.vault_storage == "dynamodb" ? join("", aws_dynamodb_table.vault_storage.*.name) : ""}"
    vault_storage_dyndb_arn = "${var.vault_storage == "dynamodb" ? join("", aws_dynamodb_table.vault_storage.*.arn) : ""}"
}


# ===================================================================
# Resources
# ===================================================================

# Create a DynamoDB table and scaling policies to store vault data
resource "aws_dynamodb_table" "vault_storage" {
    count = "${var.vault_storage == "dynamodb" ? 1 : 0}"

    name = "${var.project}-storage"
    read_capacity = "${var.vault_storage_dyndb_min_rcu}"
    write_capacity = "${var.vault_storage_dyndb_min_wcu}"

    hash_key = "Path"
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
        enabled = true
    }

    point_in_time_recovery {
        enabled = true
    }

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "${var.data_classification}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        ignore_changes = [
            "read_capacity",
            "write_capacity",
        ]

        prevent_destroy = true
    }
}


# Autoscale the RCU
resource "aws_appautoscaling_target" "vault_storage_dyndb_rcu" {
    count = "${var.vault_storage == "dynamodb" ? 1 : 0}"

    service_namespace = "dynamodb"
    resource_id = "table/${element(aws_dynamodb_table.vault_storage.*.name, count.index)}"

    scalable_dimension = "dynamodb:table:ReadCapacityUnits"
    min_capacity = "${var.vault_storage_dyndb_min_rcu}"
    max_capacity = "${var.vault_storage_dyndb_max_rcu}"

    role_arn = "${data.aws_iam_role.appautoscaling_dynamodb.arn}"
}
resource "aws_appautoscaling_policy" "vault_storage_dyndb_rcu" {
    count = "${var.vault_storage == "dynamodb" ? 1 : 0}"

    name = "DynamoDBReadCapacityUtilization:table/${element(aws_dynamodb_table.vault_storage.*.name, count.index)}"

    policy_type = "TargetTrackingScaling"
    service_namespace = "dynamodb"
    resource_id = "table/${element(aws_dynamodb_table.vault_storage.*.name, count.index)}"

    scalable_dimension = "dynamodb:table:ReadCapacityUnits"

    target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
            predefined_metric_type = "DynamoDBReadCapacityUtilization"
        }

        target_value = "${var.vault_storage_dyndb_rcu_target}"
    }
}

# Autoscale the WCU
resource "aws_appautoscaling_target" "vault_storage_dyndb_wcu" {
    count = "${var.vault_storage == "dynamodb" ? 1 : 0}"

    service_namespace = "dynamodb"
    resource_id = "table/${element(aws_dynamodb_table.vault_storage.*.name, count.index)}"

    scalable_dimension = "dynamodb:table:WriteCapacityUnits"
    min_capacity = "${var.vault_storage_dyndb_min_wcu}"
    max_capacity = "${var.vault_storage_dyndb_max_wcu}"

    role_arn = "${data.aws_iam_role.appautoscaling_dynamodb.arn}"
}
resource "aws_appautoscaling_policy" "vault_storage_dyndb_wcu" {
    count = "${var.vault_storage == "dynamodb" ? 1 : 0}"

    name = "DynamoDBWriteCapacityUtilization:table/${element(aws_dynamodb_table.vault_storage.*.name, count.index)}"

    policy_type = "TargetTrackingScaling"
    service_namespace = "dynamodb"
    resource_id = "table/${element(aws_dynamodb_table.vault_storage.*.name, count.index)}"

    scalable_dimension = "dynamodb:table:WriteCapacityUnits"

    target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
            predefined_metric_type = "DynamoDBWriteCapacityUtilization"
        }

        target_value = "${var.vault_storage_dyndb_wcu_target}"
    }
}
