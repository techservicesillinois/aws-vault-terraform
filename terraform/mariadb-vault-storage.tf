# ===================================================================
# Locals
# ===================================================================

locals {
    vault_storage_mariadb = "${contains(var.vault_storage, "mariadb")}"
    vault_storage_mariadb_address = "${join("", aws_db_instance.vault_storage_mariadb.*.address)}"
    vault_storage_mariadb_port = "${join("", aws_db_instance.vault_storage_mariadb.*.port)}"
    vault_storage_mariadb_admin_password = "${join("", random_string.vault_storage_mariadb_admin_password.*.result)}"
}


# ===================================================================
# Resources
# ===================================================================

# Main database security group.
resource "aws_security_group" "vault_storage_mariadb" {
    count = "${local.vault_storage_mariadb ? 1 : 0}"

    name_prefix = "${var.project}-storage-"
    description = "Group for the vault storage database."
    vpc_id = "${data.aws_vpc.private.id}"

    # Only allow DB connections from the admin instance and our PHP backends.
    ingress {
        protocol = "tcp"
        from_port = 3306
        to_port = 3306
        security_groups = [
            "${aws_security_group.vault_server_app.id}",
        ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags {
        Name = "${var.project}-storage"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

# Subnet group with the private subnets so that the RDS instances deploy in
# the right place.
resource "aws_db_subnet_group" "vault_storage_mariadb" {
    count = "${local.vault_storage_mariadb ? 1 : 0}"

    name_prefix = "${var.project}-storage-"
    description = "Private subnets for the MariaDB instance."

    subnet_ids = [ "${data.aws_subnet.private.*.id}" ]

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}


resource "random_string" "vault_storage_mariadb_admin_password" {
    count = "${local.vault_storage_mariadb ? 1 : 0}"

    length = 32

    upper = true
    min_upper = 2

    lower = true
    min_lower = 2

    number = true
    min_numeric = 1

    special = false
}

resource "random_string" "vault_storage_mariadb_app_password" {
    count = "${local.vault_storage_mariadb ? 1 : 0}"

    length = 32

    upper = true
    min_upper = 2

    lower = true
    min_lower = 2

    number = true
    min_numeric = 1

    special = false
}


resource "aws_db_instance" "vault_storage_mariadb" {
    count = "${local.vault_storage_mariadb ? 1 : 0}"

    identifier_prefix = "${var.project}-storage-"
    engine = "mariadb"
    engine_version = "${var.vault_storage_mariadb_version}"
    auto_minor_version_upgrade = true
    allow_major_version_upgrade = false

    multi_az = "${length(data.aws_subnet.private.*.id) > 1 ? 1 : 0}"
    vpc_security_group_ids = [
        "${element(aws_security_group.vault_storage_mariadb.*.id, count.index)}",
    ]
    db_subnet_group_name = "${element(aws_db_subnet_group.vault_storage_mariadb.*.id, count.index)}"

    instance_class = "${var.vault_storage_mariadb_class}"
    allocated_storage = "${var.vault_storage_mariadb_size}"
    storage_type = "gp2"
    storage_encrypted = true
    kms_key_id = "${aws_kms_key.vault.arn}"

    username = "${var.vault_storage_mariadb_admin_username}"
    password = "${element(random_string.vault_storage_mariadb_admin_password.*.result, count.index)}"

    backup_retention_period = "${var.vault_storage_mariadb_backup_retention}"
    backup_window = "${var.vault_storage_mariadb_backup_window}"
    maintenance_window = "${var.vault_storage_mariadb_maintenance_window}"

    monitoring_role_arn = "${var.vault_storage_mariadb_monitoring == 0 ? "" : data.aws_iam_role.rds_monitoring.arn}"
    monitoring_interval = "${var.vault_storage_mariadb_monitoring == 0 ? 0 : 60}"

    copy_tags_to_snapshot = true
    deletion_protection = true

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "${var.data_classification}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        prevent_destroy = true
    }
}
