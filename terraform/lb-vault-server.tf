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
    }

    egress {
        protocol = "-1"
        from_port = 0
        to_port = 0

        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags {
        Name = "${var.project}-lb"

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
