service = "ICS Vault"
contact = "sbutler1@illinois.edu"
data_classification = "Internal"
environment = "Development"

project = "sbutler1-vault"
key_name = "sbutler1@illinois.edu"
key_file = "~/.ssh/main-work"

deploy_bucket = "uiuc-sbutler1-sandbox"
deploy_prefix = "vault/"

sss_bind_user = "CITES-ICS-LDAPQuery@ad.uillinois.edu"

vault_server_admin_groups = [
    "ICS Admins",
]
vault_server_fqdns = [
    "sbutler1-vault-a.ics.illinois.edu",
    "sbutler1-vault-b.ics.illinois.edu",
]
vault_server_private_ips = [
    "10.224.255.51",
    "10.224.255.181",
]

vault_storage_min_rcu = 1
vault_storage_min_wcu = 1
