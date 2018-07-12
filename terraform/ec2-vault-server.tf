# =========================================================
# Locals
# =========================================================

locals {
    ecs_instance_ansible_extravars = {
        project = "${var.project}"
        region = "${data.aws_region.current.name}"

        sss_bindcreds_bucket = "${var.deploy_bucket}"
        sss_bindcreds_object = "${var.deploy_prefix}ldap-credentials.txt"
        sss_allow_groups = "${lower(join(", ", var.vault_server_admin_groups))}"

        ssh_allow_groups = "${lower(join(" ", formatlist("\"%s\"", var.vault_server_admin_groups)))}"

        sudo_admin_groups = "${var.vault_server_admin_groups}"
    }

    vault_server_ansible_extravars = {
        project = "${var.project}"
        region = "${data.aws_region.current.name}"

        tls_bucket = "${var.deploy_bucket}"
        tls_crt_object = "${var.deploy_prefix}server.crt"
        tls_key_object = "${var.deploy_prefix}server.key"

        vault_image = "${local.vault_server_image}"
        vault_storage = "${aws_dynamodb_table.vault_storage.name}"
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


resource "aws_security_group" "vault_server" {
    name_prefix = "${var.project}-"
    description = "Allow vault traffic."

    vpc_id = "${data.aws_vpc.public.id}"

    ingress {
        description = "Vault application"

        protocol = "tcp"
        from_port = 8200
        to_port = 8200

        cidr_blocks = [
            "0.0.0.0/0",
        ]
        ipv6_cidr_blocks = [
            "::/0",
        ]
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
        Name = "${var.project}-server"

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
    vpc_security_group_ids = [ "${distinct(concat(
        list("${aws_security_group.uiuc_campus_ssh.id}", "${aws_security_group.vault_server.id}"),
        "${aws_security_group.extra_ssh.*.id}",
    ))}" ]

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
