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

variable "vault_server_fqdn" {
    type = "string"
    description = "Fully qualified domain name of the single endpoint for the vault server (load balancer)."
    default = ""
}

variable "vault_server_public_fqdns" {
    type = "list"
    description = "Fully qualified domain name of the vault servers, one per public subnet."
}

variable "vault_server_instance_type" {
    type = "string"
    description = "Instance type to launch for the servers."
    default = "t2.small"
}

variable "vault_server_image" {
    type = "string"
    description = "Docker image to use for the vault server container."
    default = "vault:latest"
}

variable "vault_helper_image" {
    type = "string"
    description = "Docker image to use for the vault helper container."
    default = "sbutler/uiuc-vault-helper:latest"
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


# =========================================================
# Docker generic maps
# =========================================================

# Docker: map a host instance type to the main task's CPU reservation.
# Calculated as 50% the number of CPU units available for the type.
variable "docker_instance2cpu" {
    type = "map"
    default = {
        t2.micro            = 512
        t2.small            = 512
        t2.medium           = 1024
        t2.large            = 1024
        t2.xlarge           = 2048
        t2.2xlarge          = 4096

        m5.large            = 1024
        m5.xlarge           = 2048
        m5.2xlarge          = 4096
        m5.4xlarge          = 8192
        m5.12xlarge         = 24576
        m5.24xlarge         = 49152
        m5d.large           = 1024
        m5d.xlarge          = 2048
        m5d.2xlarge         = 4096
        m5d.4xlarge         = 8192
        m5d.12xlarge        = 24576
        m5d.24xlarge        = 49152

        m4.large            = 1024
        m4.xlarge           = 2048
        m4.2xlarge          = 4096
        m4.4xlarge          = 8192
        m4.10xlarge         = 20480
        m4.16xlarge         = 32768

        m3.medium           = 512
        m3.large            = 1024
        m3.xlarge           = 2048
        m3.2xlarge          = 4096

        c5.large            = 1024
        c5.xlarge           = 2048
        c5.2xlarge          = 4096
        c5.4xlarge          = 8192
        c5.9xlarge          = 18432
        c5.18xlarge         = 36864
        c5d.large           = 1024
        c5d.xlarge          = 2048
        c5d.2xlarge         = 4096
        c5d.4xlarge         = 8192
        c5d.9xlarge         = 18432
        c5d.18xlarge        = 36864

        c4.large            = 1024
        c4.xlarge           = 2048
        c4.2xlarge          = 4096
        c4.4xlarge          = 8192
        c4.8xlarge          = 18432

        c3.large            = 1024
        c3.xlarge           = 2048
        c3.2xlarge          = 4096
        c3.4xlarge          = 8192
        c3.8xlarge          = 16384

        g3.4xlarge          = 8192
        g3.8xlarge          = 16384
        g3.16xlarge         = 32768

        g2.2xlarge          = 4096
        g2.8xlarge          = 16384

        p3.2xlarge          = 4096
        p3.8xlarge          = 16384
        p3.16xlarge         = 32768

        p2.xlarge           = 2048
        p2.8xlarge          = 16384
        p2.16xlarge         = 32768

        r4.large            = 1024
        r4.xlarge           = 2048
        r4.2xlarge          = 4096
        r4.4xlarge          = 8192
        r4.8xlarge          = 16384
        r4.16xlarge         = 32768

        r3.large            = 1024
        r3.xlarge           = 2048
        r3.2xlarge          = 4096
        r3.4xlarge          = 8192
        r3.8xlarge          = 16384

        x1e.xlarge          = 2048
        x1e.2xlarge         = 4096
        x1e.4xlarge         = 8192
        x1e.8xlarge         = 16384
        x1e.16xlarge        = 32768
        x1e.32xlarge        = 65536

        x1.16xlarge         = 32768
        x1.32xlarge         = 65536
    }
}

# Docker: map the host instance type to the main task's RAM limit.
# Calculated as the (Total RAM) - 512M.
variable "docker_instance2memory" {
    type = "map"
    default = {
        t2.micro            = 512
        t2.small            = 1536
        t2.medium           = 3584
        t2.large            = 7680
        t2.xlarge           = 15872
        t2.2xlarge          = 32256

        m5.large            = 7680
        m5.xlarge           = 15872
        m5.2xlarge          = 32256
        m5.4xlarge          = 65024
        m5.12xlarge         = 196096
        m5.24xlarge         = 392704
        m5d.large           = 7680
        m5d.xlarge          = 15872
        m5d.2xlarge         = 32256
        m5d.4xlarge         = 65024
        m5d.12xlarge        = 196096
        m5d.24xlarge        = 390656

        m4.large            = 7680
        m4.xlarge           = 15872
        m4.2xlarge          = 32256
        m4.4xlarge          = 65024
        m4.10xlarge         = 163328
        m4.16xlarge         = 261632

        m3.medium           = 3328
        m3.large            = 7168
        m3.xlarge           = 14848
        m3.2xlarge          = 30208

        c5.large            = 3584
        c5.xlarge           = 7680
        c5.2xlarge          = 15872
        c5.4xlarge          = 32256
        c5.9xlarge          = 73216
        c5.18xlarge         = 146944
        c5d.large           = 3584
        c5d.xlarge          = 7680
        c5d.2xlarge         = 15872
        c5d.4xlarge         = 32256
        c5d.9xlarge         = 73216
        c5d.18xlarge        = 146944

        c4.large            = 3328
        c4.xlarge           = 7168
        c4.2xlarge          = 14848
        c4.4xlarge          = 30208
        c4.8xlarge          = 60928

        c3.large            = 3328
        c3.xlarge           = 7168
        c3.2xlarge          = 14848
        c3.4xlarge          = 30208
        c3.8xlarge          = 60928

        g3.4xlarge          = 124416
        g3.8xlarge          = 249344
        g3.16xlarge         = 499200

        g2.2xlarge          = 14848
        g2.8xlarge          = 60928

        p3.2xlarge          = 61952
        p3.8xlarge          = 249344
        p3.16xlarge         = 499200

        p2.xlarge           = 61952
        p2.8xlarge          = 499200
        p2.16xlarge         = 749056

        r4.large            = 15104
        r4.xlarge           = 30720
        r4.2xlarge          = 61952
        r4.4xlarge          = 124416
        r4.8xlarge          = 249344
        r4.16xlarge         = 499200

        r3.large            = 15104
        r3.xlarge           = 30720
        r3.2xlarge          = 61952
        r3.4xlarge          = 124416
        r3.8xlarge          = 249344

        x1e.xlarge          = 124416
        x1e.2xlarge         = 249344
        x1e.4xlarge         = 499200
        x1e.8xlarge         = 998912
        x1e.16xlarge        = 1998336
        x1e.32xlarge        = 3997184

        x1.16xlarge         = 998912
        x1.32xlarge         = 1998336
    }
}

# Docker: map the host instance type to the main task's RAM reservation.
# A default vault is calculated of (Total RAM - 512) / 2, but you can
# override the key for your instance type and change that value with
# this map.
variable "docker_instance2memoryres" {
    type = "map"
    default = {
    }
}
