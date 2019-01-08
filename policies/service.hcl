path "secret/service/metadata/" {
  capabilities = ["list"]
}

path "secret/service/data/example/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "secret/service/delete/example/*" {
  capabilities = ["update"]
}

path "secret/service/metadata/example/*" {
  capabilities = ["read", "list"]
}
