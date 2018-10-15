output "vault_key_id" {
    value = "${aws_kms_key.vault.id}"
}

output "vault_master_arn" {
    value = "${aws_secretsmanager_secret.vault_master.arn}"
}

output "vault_server_lb" {
    value = "${join("", aws_lb.vault_server.*.dns_name)}"
}

output "vault_server_public_ips" {
    value = "${aws_eip.vault_server.*.public_ip}"
}

output "vault_storage_dyndb_name" {
    value = "${local.vault_storage_dyndb_name}"
}
