path "secret/unit/data/example/*" {
  capabilities = ["delete"]
}

path "secret/unit/delete/example/*" {
  capabilities = ["update"]
}

path "secret/unit/undelete/example/*" {
  capabilities = ["update"]
}

path "secret/unit/destroy/example/*" {
  capabilities = ["update"]
}

path "secret/unit/metadata/example/*" {
  capabilities = ["update", "delete"]
}
