# ===================================================================
# Resources
# ===================================================================

resource "aws_security_group" "vault_server_lb" {
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


resource "aws_lb" "vault_server" {
    count = "${length(var.vault_server_fqdn) == 0 ? 0 : 1}"

    name_prefix = "vault-"
    load_balancer_type = "application"

    subnets = [ "${data.aws_subnet.public.*.id}" ]
    security_groups = [
        "${aws_security_group.vault_server_lb.id}",
    ]
    internal = false

    tags {
        Name = "${var.vault_server_fqdn}"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

resource "aws_lb_target_group" "vault_server" {
    count = "${length(var.vault_server_fqdn) == 0 ? 0 : 1}"

    name_prefix = "vault-"
    vpc_id = "${data.aws_vpc.public.id}"

    port = 8200
    protocol = "HTTPS"
    target_type = "instance"
    slow_start = 30

    health_check {
        interval = 30
        timeout = 10

        port = 8200
        protocol = "HTTPS"

        path = "/v1/sys/health"
        matcher = "200,429"
    }

    tags {
        Name = "${var.vault_server_fqdn}"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}
resource "aws_lb_target_group_attachment" "vault_server" {
    count = "${length(var.vault_server_fqdn) == 0 ? 0 : length(data.aws_subnet.public.*.id)}"

    target_group_arn = "${aws_lb_target_group.vault_server.arn}"
    target_id = "${element(aws_instance.vault_server.*.id, count.index)}"
}

resource "aws_lb_listener" "vault_server" {
    count = "${length(var.vault_server_fqdn) == 0 ? 0 : 1}"

    load_balancer_arn = "${aws_lb.vault_server.arn}"

    port = 8200
    protocol = "HTTPS"
    ssl_policy = "ELBSecurityPolicy-FS-2018-06"
    certificate_arn = "${data.aws_acm_certificate.vault_server.arn}"

    default_action {
        type = "forward"
        target_group_arn = "${aws_lb_target_group.vault_server.arn}"
    }
}
