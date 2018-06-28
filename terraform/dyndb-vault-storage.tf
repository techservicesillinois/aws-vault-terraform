# ===================================================================
# Resources
# ===================================================================

# Create a DynamoDB table and scaling policies to store vault data
resource "aws_dynamodb_table" "vault_storage" {
    name = "${var.project}-storage"
    read_capacity = "${var.vault_storage_min_rcu}"
    write_capacity = "${var.vault_storage_min_wcu}"

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

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        ignore_changes = [
            "read_capacity",
            "write_capacity",
        ]
    }
}


# Autoscale the RCU
resource "aws_appautoscaling_target" "vault_storage_rcu" {
  service_namespace = "dynamodb"
  resource_id = "table/${aws_dynamodb_table.vault_storage.name}"

  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  min_capacity = "${var.vault_storage_min_rcu}"
  max_capacity = "${var.vault_storage_max_rcu}"

  role_arn = "${data.aws_iam_role.appautoscaling_dynamodb.arn}"
}
resource "aws_appautoscaling_policy" "vault_storage_rcu" {
  name = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.vault_storage_rcu.resource_id}"

  policy_type = "TargetTrackingScaling"
  service_namespace = "${aws_appautoscaling_target.vault_storage_rcu.service_namespace}"
  resource_id = "${aws_appautoscaling_target.vault_storage_rcu.resource_id}"

  scalable_dimension = "${aws_appautoscaling_target.vault_storage_rcu.scalable_dimension}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = "${var.vault_storage_rcu_target}"
  }
}

# Autoscale the WCU
resource "aws_appautoscaling_target" "vault_storage_wcu" {
  service_namespace = "dynamodb"
  resource_id = "table/${aws_dynamodb_table.vault_storage.name}"

  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  min_capacity = "${var.vault_storage_min_wcu}"
  max_capacity = "${var.vault_storage_max_wcu}"

  role_arn = "${data.aws_iam_role.appautoscaling_dynamodb.arn}"
}
resource "aws_appautoscaling_policy" "vault_storage_wcu" {
  name = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.vault_storage_wcu.resource_id}"

  policy_type = "TargetTrackingScaling"
  service_namespace = "${aws_appautoscaling_target.vault_storage_wcu.service_namespace}"
  resource_id = "${aws_appautoscaling_target.vault_storage_wcu.resource_id}"

  scalable_dimension = "${aws_appautoscaling_target.vault_storage_wcu.scalable_dimension}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = "${var.vault_storage_wcu_target}"
  }
}
