path "secret/unit/metadata/" {
  capabilities = ["list"]
}

path "secret/unit/data/example/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "secret/unit/delete/example/*" {
  capabilities = ["update"]
}

path "secret/unit/metadata/example/*" {
  capabilities = ["read", "list"]
}
