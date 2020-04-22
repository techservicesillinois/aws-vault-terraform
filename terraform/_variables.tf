# =========================================================
# Cloud First
# =========================================================

variable "service" {
    type        = string
    description = "Service name (match Service Catalog where possible)."
}

variable "contact" {
    type        = string
    description = "Service email address."
}

variable "data_classification" {
    type        = string
    description = "Public, Internal, Sensitive, or HighRisk (choose the most rigorous standard that applies)."
}

variable "environment" {
    type        = string
    description = "Production, Test, Development, Green, Blue, etc."
    default     = ""
}

# =========================================================
# Base
# =========================================================

variable "project" {
    type        = string
    description = "Name for the infrastructure project. This will be included in resource names and tags where possible."
}

variable "key_name" {
    type        = string
    description = "SSH key name to use for instances."
}

variable "key_file" {
    type        = string
    description = "SSH private key file to use for connecting to intances."
}

variable "enhanced_monitoring" {
    type        = bool
    description = "Use enahanced/detailed monitoring on supported resources."
    default     = false
}

variable "public_subnets" {
    type        = list(string)
    description = "Public subnet names for resources publically accessible."
}

variable "private_subnets" {
    type        = list(string)
    description = "Private subnet names for resources not publically accessible."
}

variable "campus_cidrs" {
    type        = map(list(string))
    description = "Campus CIDR ranges to use for various security group rules if allow campus is true. The default should be fine, but if you override this you must specify all ranges."
    default = {
        UIUC = [
            "72.36.64.0/18",
            "128.174.0.0/16",
            "130.126.0.0/16",
            "192.17.0.0/16",
            "10.192.0.0/10",
            "172.16.0.0/13",
        ]
        UA = [
            "64.22.176.0/20",
            "204.93.0.0/19",
        ]
        NCSA = [
            "141.142.0.0/16",
            "198.17.196.0/25",
            "172.24.0.0/13",
        ]
    }
}

variable "ssh_allow_campus" {
    type        = bool
    description = "Allow the campus subnet ranges to SSH to the Vault server instances."
    default     = true
}

variable "ssh_allow_cidrs" {
    type        = map(list(string))
    description = "CIDRs allowed to SSH to the admin instance. Each key will be used as part of the description for the security group. Use 'ssh_allow_campus' to allow all campus ranges."
    default     = {}
}

variable "app_allow_campus" {
    type        = bool
    description = "Allow the campus subnet ranges to access the Vault server application ports."
    default     = true
}

variable "app_allow_cidrs" {
    type        = map(list(string))
    description = "CIDRs allowed to access the Vault application ports. Each key will be used as part of the description for the security group. Use 'app_allow_campus' to allow all campus ranges."
    default     = {}
}

variable "deploy_bucket" {
    type        = string
    description = "Bucket name to deploy resources from."
}

variable "deploy_prefix" {
    type        = string
    description = "Prefix to use for locating resources in the deployment bucket."
    default     = ""
}

variable "log_levels" {
    type        = map(string)
    description = "Map environment names to logging levels. The default is 'info' if nothing is specified."
    default = {
        "Development" = "debug"
        "development" = "debug"
        "Dev"         = "debug"
        "dev"         = "debug"
    }
}

# =========================================================
# Vault Server
# =========================================================

variable "vault_key_user_roles" {
    type        = list(string)
    description = "Extra role names to grant to the KMS key for usage."
    default     = []
}

variable "vault_server_admin_groups" {
    type        = list(string)
    description = "AD groups allowed to admin the vault server."
}

variable "vault_server_private_ips" {
    type        = list(string)
    description = "Private IP's in the public subnets to use for the servers."
    default     = [ null ]
}

variable "vault_server_fqdn" {
    type        = string
    description = "Fully qualified domain name of the single endpoint for the vault server (load balancer)."
    default     = null
}

variable "vault_server_public_fqdns" {
    type        = list(string)
    description = "Fully qualified domain name of the vault servers, one per public subnet."
}

variable "vault_server_instance_type" {
    type        = string
    description = "Instance type to launch for the servers."
    default     = "t3.small"
}

variable "vault_server_image" {
    type        = string
    description = "Docker image to use for the vault server container."
    default     = "vault:latest"
}

variable "vault_helper_image" {
    type        = string
    description = "Docker image to use for the vault helper container."
    default     = "sbutler/uiuc-vault-helper:latest"
}

variable "vault_storage" {
    type        = list(string)
    description = "Type of storage to use for vault server (dynamodb, mariadb). The first list item will be the primary storage, but all items will be provisioned (useful for migrations)."
    default     = [ "dynamodb" ]
}

# =========================================================
# Vaul Storage: DynamoDB
# =========================================================

variable "vault_storage_dyndb_max_parallel" {
    type        = number
    description = "Maximum number of parallel operations vault server will perform when using this backend."
    default     = 128
}

# =========================================================
# Vaul Storage: MariaDB
# =========================================================

variable "vault_storage_mariadb_version" {
    type        = string
    description = "MariaDB version, only major and minor components specified."
    default     = "10.2"
}

variable "vault_storage_mariadb_class" {
    type        = string
    description = "MariaDB instance class for RDS."
    default     = "db.t3.small"
}

variable "vault_storage_mariadb_size" {
    type        = number
    description = "MariaDB storage volume size, in GB. This should be at least 5."
    default     = 5
}

variable "vault_storage_mariadb_max_parallel" {
    type        = number
    description = "Maximum number of parallel operations for vault to perform. If not specified then 90% of the database max connections is used."
    default     = null
}

variable "vault_storage_mariadb_admin_username" {
    type        = string
    description = "MariaDB administartor username. The password will be randomly generated."
    default     = "vault_admin"
}

variable "vault_storage_mariadb_app_username" {
    type        = string
    description = "MariaDB vault application username. The password will be randomly generated."
    default     = "vault_server"
}

variable "vault_storage_mariadb_backup_retention" {
    type        = number
    description = "MariaDB backup retention, in days."
    default     = 30
}

variable "vault_storage_mariadb_backup_window" {
    type        = string
    description = "MariaDB backup window as HH:MM-HH:MM in UTC time. This must not overlap the maintenance window."
    default     = "09:00-10:00"
}

variable "vault_storage_mariadb_maintenance_window" {
    type        = string
    description = "MariaDB maintenance window as DDD:HH:MM-DDDD:HH:MM in UTC time. This must not overlap the backup window."
    default     = "Sun:07:00-Sun:08:00"
}

# =========================================================
# Docker generic maps
# =========================================================

# Docker: map a host instance type to the main task's CPU reservation.
# Calculated as 50% the number of CPU units available for the type.
variable "docker_instance2cpu" {
    type    = map(number)
    default = {}
}

# Docker: map the host instance type to the main task's RAM limit.
# Calculated as the (Total RAM) - 512M.
variable "docker_instance2memory" {
    type    = map(number)
    default = {}
}

# Docker: map the host instance type to the main task's RAM reservation.
# A default vault is calculated of (Total RAM - 512) / 2, but you can
# override the key for your instance type and change that value with
# this map.
variable "docker_instance2memoryres" {
    type    = map(number)
    default = {}
}
