# =========================================================
# Locals
# =========================================================

locals {
    ecs_instance_ansible_extravars = {
        project = var.project
        region  = data.aws_region.current.name
        contact = var.contact

        sudo_admin_groups = var.vault_server_admin_groups
    }

    vault_server_ansible_extravars = {
        project = var.project
        region  = data.aws_region.current.name

        lb_subnet_cidrs = join(",", data.aws_subnet.public[*].cidr_block)

        kms_key_id = aws_kms_key.vault.id

        tls_bucket     = var.deploy_bucket
        tls_crt_object = "${var.deploy_prefix}server.crt"
        tls_key_object = "${var.deploy_prefix}server.key"

        vault_image   = local.vault_server_image
        vault_storage = var.vault_storage

        dyndb_name         = local.vault_storage_dyndb_name
        dyndb_max_parallel = var.vault_storage_dyndb_max_parallel

        mariadb_host         = local.vault_storage_mariadb_address
        mariadb_port         = local.vault_storage_mariadb_port
        mariadb_admin_user   = var.vault_storage_mariadb_admin_username
        mariadb_admin_pass   = random_string.vault_storage_mariadb_admin_password.result
        mariadb_app_db       = "vault-server"
        mariadb_app_user     = var.vault_storage_mariadb_app_username
        mariadb_app_pass     = random_string.vault_storage_mariadb_app_password.result
        mariadb_max_parallel = var.vault_storage_mariadb_max_parallel
    }
}

# =========================================================
# Data
# =========================================================

data "template_file" "vault_server_config" {
    count = length(data.aws_subnet.public)

    template = file("${path.module}/templates/cloud-init/ecs-config.yml.tpl")

    vars = {
        fqdn     = var.vault_server_public_fqdns[count.index]
        hostname = replace(var.vault_server_public_fqdns[count.index], "/^([^.]+)(\\..*)$/", "$1")
    }
}

data "template_file" "vault_server_configscript" {
    template = file("${path.module}/templates/cloud-init/ecs-configscript.sh.tpl")

    vars = {
        project      = var.project
        cluster_name = aws_ecs_cluster.vault_server.name

        ssh_allow_groups = lower(
            join(" ", formatlist("\"%s\"", var.vault_server_admin_groups)),
        )

        sss_bindcreds_bucket = var.deploy_bucket
        sss_bindcreds_object = "${var.deploy_prefix}ldap-credentials.txt"
        sss_allow_groups     = lower(join(", ", var.vault_server_admin_groups))
    }
}

data "template_cloudinit_config" "vault_server_userdata" {
    count = length(data.aws_subnet.public)

    part {
        filename     = "init.sh"
        content_type = "text/cloud-boothook"
        content      = data.template_file.vault_server_configscript.rendered
    }

    part {
        filename     = "urls.txt"
        content_type = "text/x-include-url"
        content = <<HERE
https://static.ics.illinois.edu/cloud-init/20200421/sss.sh
https://static.ics.illinois.edu/cloud-init/20200421/cis.sh
https://static.ics.illinois.edu/cloud-init/20200421/ecslogs.yml
HERE
    }

    part {
        filename     = "config.yml"
        content_type = "text/cloud-config"
        content      = data.template_file.vault_server_config[count.index].rendered
    }
}

# =========================================================
# Resources
# =========================================================

resource "aws_eip" "vault_server" {
    count = length(data.aws_subnet.public)

    vpc = true
    tags = {
        Name        = var.vault_server_public_fqdns[count.index]
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }

    lifecycle {
        prevent_destroy = true
    }
}

resource "aws_security_group" "vault_server_app" {
    name_prefix = "${var.project}-"
    description = "Allow vault traffic."

    vpc_id = data.aws_vpc.public.id

    dynamic "ingress" {
        for_each = merge(
            var.app_allow_campus ? var.campus_cidrs : {},
            var.app_allow_cidrs,
        )

        content {
            description = "Vault application (${ingress.key})"

            protocol  = "tcp"
            from_port = 8200
            to_port   = 8200

            cidr_blocks = ingress.value
        }
    }

    ingress {
        description = "Vault application (load balancer)"

        protocol  = "tcp"
        from_port = 8200
        to_port   = 8200

        security_groups = [ aws_security_group.vault_server_lb.id ]
    }

    ingress {
        description = "Vault application (load balancer)"

        protocol  = "tcp"
        from_port = 8220
        to_port   = 8220

        security_groups = [ aws_security_group.vault_server_lb.id ]
    }

    ingress {
        description = "Vault cluster"

        protocol  = "tcp"
        from_port = 8200
        to_port   = 8220

        self = true
    }

    egress {
        protocol  = "-1"
        from_port = 0
        to_port   = 0

        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name        = "${var.project}-app"
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_security_group" "vault_server_ssh" {
    name_prefix = "${var.project}-"
    description = "Allow SSH from approved addresses."

    vpc_id = data.aws_vpc.public.id

    dynamic "ingress" {
        for_each = merge(
            var.ssh_allow_campus ? var.campus_cidrs : {},
            var.ssh_allow_cidrs,
        )
        content {
            description = "SSH (${ingress.key})"

            protocol  = "tcp"
            from_port = 22
            to_port   = 22

            cidr_blocks = ingress.value
        }
    }

    tags = {
        Name        = "${var.project}-ssh"
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_instance" "vault_server" {
    count = length(data.aws_subnet.public)

    ami                  = data.aws_ami.ecs_optimized2.id
    instance_type        = var.vault_server_instance_type
    key_name             = var.key_name
    iam_instance_profile = aws_iam_instance_profile.vault_server.name

    availability_zone = data.aws_subnet.public[count.index].availability_zone
    subnet_id         = data.aws_subnet.public[count.index].id
    private_ip        = element(var.vault_server_private_ips, count.index)
    vpc_security_group_ids = [
        aws_security_group.vault_server_app.id,
        aws_security_group.vault_server_ssh.id,
    ]

    instance_initiated_shutdown_behavior = "stop"
    monitoring                           = var.enhanced_monitoring

    user_data = data.template_cloudinit_config.vault_server_userdata[count.index].rendered

    credit_specification {
        cpu_credits = contains(["t2", "t3"], substr(var.vault_server_instance_type, 0, 2)) ? "unlimited" : null
    }

    root_block_device {
        volume_type = "gp2"
        volume_size = 30

        encrypted  = true
        kms_key_id = aws_kms_key.vault.arn

        delete_on_termination = true
    }

    tags = {
        Name               = var.vault_server_public_fqdns[count.index]
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }

    volume_tags = {
        Name               = var.vault_server_public_fqdns[count.index]
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }

    lifecycle {
        ignore_changes = [
            ami,
            user_data,
        ]
    }
}

resource "aws_eip_association" "vault_server" {
    count = length(data.aws_subnet.public)

    allocation_id = aws_eip.vault_server[count.index].id
    instance_id   = aws_instance.vault_server[count.index].id
}

resource "null_resource" "ecs_instance_ansible" {
    depends_on = [
        aws_eip_association.vault_server,
        null_resource.wait_vault_server_role,
    ]

    triggers = {
        ansible_md5       = filemd5("${path.module}/files/ansible/ecs-instance.yml")
        ansible_extravars = jsonencode(local.ecs_instance_ansible_extravars)
        instance_ids      = join(",", aws_instance.vault_server[*].id)
    }

    provisioner "local-exec" {
        command = "ansible-playbook -i '${join(",", aws_eip.vault_server[*].public_ip)},' -e '${jsonencode(local.ecs_instance_ansible_extravars)}' '${path.module}/files/ansible/ecs-instance.yml'"

        environment = {
            ANSIBLE_HOST_KEY_CHECKING = "False"
            ANSIBLE_SSH_RETRIES       = "10"
            ANSIBLE_PRIVATE_KEY_FILE  = pathexpand(var.key_file)
        }
    }
}

resource "null_resource" "vault_server_ansible" {
    count      = length(data.aws_subnet.public)
    depends_on = [ null_resource.ecs_instance_ansible ]

    triggers = {
        ansible_md5       = filemd5("${path.module}/files/ansible/vault-server.yml")
        ansible_extravars = jsonencode(local.vault_server_ansible_extravars)
        instance_ids      = join(",", aws_instance.vault_server[*].id)
        cluster_addr      = aws_instance.vault_server[count.index].private_ip
        api_addr          = var.vault_server_public_fqdns[count.index]
        tls_crt_etag      = data.aws_s3_bucket_object.vault_server_tls_key.etag
        tls_key_etag      = data.aws_s3_bucket_object.vault_server_tls_crt.etag
    }

    provisioner "local-exec" {
        command = "ansible-playbook -i '${aws_eip.vault_server[count.index].public_ip},' -e 'cluster_addr=${aws_instance.vault_server[count.index].private_ip} api_addr=${var.vault_server_public_fqdns[count.index]}' -e '${jsonencode(local.vault_server_ansible_extravars)}' '${path.module}/files/ansible/vault-server.yml'"

        environment = {
            ANSIBLE_HOST_KEY_CHECKING = "False"
            ANSIBLE_SSH_RETRIES       = "10"
            ANSIBLE_PRIVATE_KEY_FILE  = pathexpand(var.key_file)
        }
    }
}
