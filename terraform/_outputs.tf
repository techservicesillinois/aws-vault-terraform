output "vault_key_id" {
    value = "${aws_kms_key.vault.id}"
}

output "vault_storage_name" {
    value = "${aws_dynamodb_table.vault_storage.name}"
}
