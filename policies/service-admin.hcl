path "secret/service/data/example/*" {
  capabilities = ["delete"]
}

path "secret/service/delete/example/*" {
  capabilities = ["update"]
}

path "secret/service/undelete/example/*" {
  capabilities = ["update"]
}

path "secret/service/destroy/example/*" {
  capabilities = ["update"]
}

path "secret/service/metadata/example/*" {
  capabilities = ["update", "delete"]
}
