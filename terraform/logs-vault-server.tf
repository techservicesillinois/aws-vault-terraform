# ===================================================================
# Resources
# ===================================================================

resource "aws_cloudwatch_log_group" "vault_server_containers" {
    name = "/${var.project}/ecs-containers/vault-server"
    retention_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    kms_key_id = "${aws_kms_key.vault.arn}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "${var.data_classification}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}
