# ===================================================================
# Data
# ===================================================================

data "aws_acm_certificate" "vault_server" {
    count = "${length(var.vault_server_fqdn) == 0 ? 0 : 1}"

    domain = "${var.vault_server_fqdn}"
    statuses = [ "PENDING_VALIDATION", "ISSUED" ]
    most_recent = true
}


data "aws_s3_bucket_object" "vault_server_tls_crt" {
    bucket = "${var.deploy_bucket}"
    key = "${var.deploy_prefix}server.crt"
}

data "aws_s3_bucket_object" "vault_server_tls_key" {
    bucket = "${var.deploy_bucket}"
    key = "${var.deploy_prefix}server.key"
}
