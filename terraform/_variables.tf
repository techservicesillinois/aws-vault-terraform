# =========================================================
# Cloud First
# =========================================================

variable "service" {
    type = "string"
    description = "Service name (match Service Catalog where possible)."
}

variable "contact" {
    type = "string"
    description = "Service email address."
}

variable "data_classification" {
    type = "string"
    description = "Public, Internal, Sensitive, or HighRisk (choose the most rigorous standard that applies)."
}

variable "environment" {
    type = "string"
    description = "Production, Test, Development, Green, Blue, etc."
    default = ""
}


# =========================================================
# Base
# =========================================================

variable "project" {
    type = "string"
    description = "Name for the infrastructure project. This will be included in resource names and tags where possible."
}

variable "key_name" {
    type = "string"
    description = "SSH key name to use for instances."
}

variable "key_file" {
    type = "string"
    description = "SSH private key file to use for connecting to intances."
}

variable "enhanced_monitoring" {
    type = "string"
    description = "Use enahanced/detailed monitoring on supported resources (0 = no; 1 = yes)."
    default = "0"
}

variable "public_subnets" {
    type = "list"
    description = "Public subnet names for resources publically accessible."
}

variable "campus_subnets" {
    type = "list"
    description = "Campus subnet names for resources with campus routes."
}

variable "private_subnets" {
    type = "list"
    description = "Private subnet names for resource not reacable by the public or campus."
}

variable "extra_admin_cidrs" {
    type = "list"
    description = "Extra CIDRs allowed to access the admin instance."
    default = []
}

variable "deploy_bucket" {
    type = "string"
    description = "Bucket name to deploy resources from."
}

variable "deploy_prefix" {
    type = "string"
    description = "Prefix to use for locating resources in the deployment bucket."
    default = ""
}

variable "secrets" {
    type = "map"
    description = "Encrypted values that will be decrypted using AWS KMS."
    default = {
    }
}

variable "ldap_query_secret" {
    type = "string"
    description = "Secrets Manager secret ID or name for LDAP querying; first line is the username and second the password."
}

# =========================================================
# Vault Server
# =========================================================

variable "vault_key_user_roles" {
    type = "list"
    description = "Extra role names to grant to the KMS key for usage."
    default = []
}

variable "vault_server_admin_groups" {
    type = "list"
    description = "AD groups allowed to admin the vault server."
}

variable "vault_server_private_ips" {
    type = "list"
    description = "Private IP's in the public subnets to use for the servers."
}

variable "vault_server_fqdns" {
    type = "list"
    description = "Fully qualified domain name of the vault servers, one per public subnet."
}

variable "vault_server_instance_type" {
    type = "string"
    description = "Instance type to launch for the servers."
    default = "t2.small"
}


# =========================================================
# Vaul Storage
# =========================================================

variable "vault_storage_max_rcu" {
    type = "string"
    description = "Vault storage maximum RCU."
    default = "20"
}

variable "vault_storage_min_rcu" {
    type = "string"
    description = "Vault storage minimum RCU."
    default = "5"
}

variable "vault_storage_max_wcu" {
    type = "string"
    description = "Vault storage maximum WCU."
    default = "20"
}

variable "vault_storage_min_wcu" {
    type = "string"
    description = "Vault storage minimum WCU."
    default = "5"
}

variable "vault_storage_rcu_target" {
    type = "string"
    description = "Vault storage target RCU utilization percentage."
    default = "70"
}

variable "vault_storage_wcu_target" {
    type = "string"
    description = "Vault storage target WCU utilization percentage."
    default = "70"
}
