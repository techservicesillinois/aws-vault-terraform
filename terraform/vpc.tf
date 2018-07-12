# ===================================================================
# Data
# ===================================================================

data "aws_subnet" "public" {
    count = "${length(var.public_subnets)}"

    state = "available"

    tags {
        Name = "${element(var.public_subnets, count.index)}"
    }
}
data "aws_vpc" "public" {
    id = "${data.aws_subnet.public.0.vpc_id}"
    state = "available"
}


# ===================================================================
# Resources
# ===================================================================

resource "aws_security_group" "uiuc_campus_ssh" {
    name_prefix = "${var.project}-"
    description = "Allow SSH from campus addresses."

    vpc_id = "${data.aws_vpc.public.id}"

    ingress {
        description = "Urbana-Champaign Campus"

        protocol = "tcp"
        from_port = 22
        to_port = 22

        cidr_blocks = [
            "72.36.64.0/18",
            "128.174.0.0/16",
            "130.126.0.0/16",
            "192.17.0.0/16",
        ]
        ipv6_cidr_blocks = [
            "2620:0:e00::/48",
        ]
    }

    ingress {
        description = "Urbana-Champaign Private"

        protocol = "tcp"
        from_port = 22
        to_port = 22

        cidr_blocks = [
            "10.192.0.0/10",
            "172.16.0.0/13",
        ]
    }

    ingress {
        description = "University Shared Services"

        protocol = "tcp"
        from_port = 22
        to_port = 22

        cidr_blocks = [
            "64.22.176.0/20",
            "204.93.0.0/19",
        ]
        ipv6_cidr_blocks = [
            "2620:79:8000::/48",
        ]
    }

    ingress {
        description = "NCSA"

        protocol = "tcp"
        from_port = 22
        to_port = 22

        cidr_blocks = [
            "141.142.0.0/16",
            "198.17.196.0/25",
        ]
        ipv6_cidr_blocks = [
            "2620:0:c80::/48",
        ]
    }

    ingress {
        description = "NCSA Private"

        protocol = "tcp"
        from_port = 22
        to_port = 22

        cidr_blocks = [
            "172.24.0.0/13",
        ]
    }

    tags {
        Name = "${var.project}-uiuc-campus-ssh"

        Service = "${var.service}"
        Contact = "${var.contact}"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}
