# =========================================================
# Locals
# =========================================================

locals {
    ecs_instance_ansible_extravars = {
        project = "${var.project}"
        region = "${data.aws_region.current.name}"
        contact = "${var.contact}"

        sss_bindcreds_bucket = "${var.deploy_bucket}"
        sss_bindcreds_object = "${var.deploy_prefix}ldap-credentials.txt"
        sss_allow_groups = "${lower(join(", ", var.vault_server_admin_groups))}"

        ssh_allow_groups = "${lower(join(" ", formatlist("\"%s\"", var.vault_server_admin_groups)))}"

        sudo_admin_groups = "${var.vault_server_admin_groups}"
    }

    vault_server_ansible_extravars = {
        project = "${var.project}"
        region = "${data.aws_region.current.name}"

        lb_subnet_cidrs = "${join(",", data.aws_subnet.public.*.cidr_block)}"

        tls_bucket = "${var.deploy_bucket}"
        tls_crt_object = "${var.deploy_prefix}server.crt"
        tls_key_object = "${var.deploy_prefix}server.key"

        vault_image = "${local.vault_server_image}"
        vault_storage = "${var.vault_storage}"

        vault_storage_dyndb_name = "${local.vault_storage_dyndb_name}"
        vault_storage_dyndb_max_parallel = "${var.vault_storage_dyndb_max_rcu * 2}"
    }
}


# =========================================================
# Data
# =========================================================

data "template_file" "vault_server_config" {
    count = "${length(data.aws_subnet.public.*.id)}"

    template = "${file("${path.module}/templates/cloud-init/ecs-config.yml.tpl")}"

    vars {
        fqdn = "${element(var.vault_server_public_fqdns, count.index)}"
        hostname = "${replace(
            element(var.vault_server_public_fqdns, count.index),
            "^([^.]+)(\\..*)$",
            "$1"
        )}"
    }
}

data "template_file" "vault_server_configscript" {
    template = "${file("${path.module}/templates/cloud-init/ecs-configscript.sh.tpl")}"

    vars {
        cluster_name = "${aws_ecs_cluster.vault_server.name}"
    }
}

data "template_cloudinit_config" "vault_server_userdata" {
    count = "${length(data.aws_subnet.public.*.id)}"

    part {
        filename = "init.sh"
        content_type = "text/cloud-boothook"
        content = "${data.template_file.vault_server_configscript.rendered}"
    }

    part {
        filename = "config.yml"
        content_type = "text/cloud-config"
        content = "${element(data.template_file.vault_server_config.*.rendered, count.index)}"
    }
}


# =========================================================
# Resources
# =========================================================

resource "aws_eip" "vault_server" {
    count = "${length(data.aws_subnet.public.*.id)}"

    vpc = true
    tags {
        Name = "${element(var.vault_server_public_fqdns, count.index)}"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        prevent_destroy = true
    }
}


resource "aws_security_group" "vault_server_app" {
    name_prefix = "${var.project}-"
    description = "Allow vault traffic."

    vpc_id = "${data.aws_vpc.public.id}"

    ingress {
        description = "Vault application"

        protocol = "tcp"
        from_port = 8200
        to_port = 8200

        cidr_blocks = [ "${distinct(concat(
            compact(list(
                var.app_allow_campus ? "72.36.64.0/18" : "",
                var.app_allow_campus ? "128.174.0.0/16" : "",
                var.app_allow_campus ? "130.126.0.0/16" : "",
                var.app_allow_campus ? "192.17.0.0/16" : "",
                var.app_allow_campus ? "10.192.0.0/10" : "",
                var.app_allow_campus ? "172.16.0.0/13" : "",
                var.app_allow_campus ? "64.22.176.0/20" : "",
                var.app_allow_campus ? "204.93.0.0/19" : "",
                var.app_allow_campus ? "141.142.0.0/16" : "",
                var.app_allow_campus ? "198.17.196.0/25" : "",
                var.app_allow_campus ? "172.24.0.0/13" : "",
            )),
            var.app_allow_cidrs,
        ))}" ]

        security_groups = [
            "${aws_security_group.vault_server_lb.id}",
        ]
        self = true
    }

    ingress {
        description = "Vault application (LB traffic)"

        protocol = "tcp"
        from_port = 8220
        to_port = 8220

        security_groups = [
            "${aws_security_group.vault_server_lb.id}",
        ]
        self = true
    }


    ingress {
        description = "Vault cluster"

        protocol = "tcp"
        from_port = 8201
        to_port = 8201

        self = true
    }

    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0

        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags {
        Name = "${var.project}-app"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

resource "aws_security_group" "vault_server_ssh" {
    name_prefix = "${var.project}-"
    description = "Allow SSH from approved addresses."

    vpc_id = "${data.aws_vpc.public.id}"

    ingress {
        protocol = "tcp"
        from_port = 22
        to_port = 22

        cidr_blocks = [ "${distinct(concat(
            compact(list(
                var.ssh_allow_campus ? "72.36.64.0/18" : "",
                var.ssh_allow_campus ? "128.174.0.0/16" : "",
                var.ssh_allow_campus ? "130.126.0.0/16" : "",
                var.ssh_allow_campus ? "192.17.0.0/16" : "",
                var.ssh_allow_campus ? "10.192.0.0/10" : "",
                var.ssh_allow_campus ? "172.16.0.0/13" : "",
                var.ssh_allow_campus ? "64.22.176.0/20" : "",
                var.ssh_allow_campus ? "204.93.0.0/19" : "",
                var.ssh_allow_campus ? "141.142.0.0/16" : "",
                var.ssh_allow_campus ? "198.17.196.0/25" : "",
                var.ssh_allow_campus ? "172.24.0.0/13" : "",
            )),
            var.ssh_allow_cidrs,
        ))}" ]
    }

    tags {
        Name = "${var.project}-ssh"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}


resource "aws_instance" "vault_server" {
    count = "${length(data.aws_subnet.public.*.id)}"

    ami = "${data.aws_ami.ecs_optimized.id}"
    instance_type = "${var.vault_server_instance_type}"
    key_name = "${var.key_name}"
    iam_instance_profile = "${aws_iam_instance_profile.vault_server.name}"

    availability_zone = "${element(data.aws_subnet.public.*.availability_zone, count.index)}"
    subnet_id = "${element(data.aws_subnet.public.*.id, count.index)}"
    private_ip = "${element(var.vault_server_private_ips, count.index)}"
    vpc_security_group_ids = [
        "${aws_security_group.vault_server_app.id}",
        "${aws_security_group.vault_server_ssh.id}",
    ]

    instance_initiated_shutdown_behavior = "stop"
    monitoring = "${var.enhanced_monitoring}"

    user_data = "${element(data.template_cloudinit_config.vault_server_userdata.*.rendered, count.index)}"

    root_block_device {
        volume_type = "gp2"
        volume_size = 8

        delete_on_termination = true
    }

    ebs_block_device {
        device_name = "/dev/xvdcz"
        encrypted = true

        volume_type = "gp2"
        volume_size = 22

        delete_on_termination = true
    }

    tags {
        Name = "${element(var.vault_server_public_fqdns, count.index)}"

        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "${var.data_classification}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    volume_tags {
        Name = "${element(var.vault_server_public_fqdns, count.index)}"

        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "${var.data_classification}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }

    lifecycle {
        ignore_changes = ["ami", "user_data"]
    }
}

resource "aws_eip_association" "vault_server" {
    count = "${length(data.aws_subnet.public.*.id)}"

    allocation_id = "${element(aws_eip.vault_server.*.id, count.index)}"
    instance_id = "${element(aws_instance.vault_server.*.id, count.index)}"
}

resource "null_resource" "ecs_instance_ansible" {
    depends_on = [
        "aws_eip_association.vault_server",
        "null_resource.wait_vault_server_role",
    ]

    triggers {
        ansible_md5 = "${md5(file("${path.module}/files/ansible/ecs-instance.yml"))}"
        ansible_extravars = "${jsonencode(local.ecs_instance_ansible_extravars)}"
    }

    provisioner "local-exec" {
        command = "ansible-playbook -i '${join(",", aws_eip.vault_server.*.public_ip)},' -e '${jsonencode(local.ecs_instance_ansible_extravars)}' '${path.module}/files/ansible/ecs-instance.yml'"

        environment {
            ANSIBLE_HOST_KEY_CHECKING = "False"
            ANSIBLE_SSH_RETRIES = "3"
            ANSIBLE_PRIVATE_KEY_FILE = "${pathexpand(var.key_file)}"
        }
    }
}

resource "null_resource" "vault_server_ansible" {
    count = "${length(data.aws_subnet.public.*.id)}"
    depends_on = [
        "null_resource.ecs_instance_ansible",
    ]

    triggers {
        ansible_md5 = "${md5(file("${path.module}/files/ansible/vault-server.yml"))}"
        ansible_extravars = "${jsonencode(local.vault_server_ansible_extravars)}"
        cluster_addr = "${element(aws_instance.vault_server.*.private_ip, count.index)}"
        api_addr = "${element(var.vault_server_public_fqdns, count.index)}"
        tls_crt_etag = "${data.aws_s3_bucket_object.vault_server_tls_key.etag}"
        tls_key_etag = "${data.aws_s3_bucket_object.vault_server_tls_crt.etag}"
    }

    provisioner "local-exec" {
        command = "ansible-playbook -i '${element(aws_eip.vault_server.*.public_ip, count.index)},' -e 'cluster_addr=${element(aws_instance.vault_server.*.private_ip, count.index)} api_addr=${element(var.vault_server_public_fqdns, count.index)}' -e '${jsonencode(local.vault_server_ansible_extravars)}' '${path.module}/files/ansible/vault-server.yml'"

        environment {
            ANSIBLE_HOST_KEY_CHECKING = "False"
            ANSIBLE_SSH_RETRIES = "3"
            ANSIBLE_PRIVATE_KEY_FILE = "${pathexpand(var.key_file)}"
        }
    }
}
