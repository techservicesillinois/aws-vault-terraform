# ===================================================================
# Data
# ===================================================================

data "aws_iam_role" "appautoscaling_dynamodb" {
    name = "AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
}
