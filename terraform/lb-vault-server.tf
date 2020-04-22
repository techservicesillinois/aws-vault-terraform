# ===================================================================
# Resources
# ===================================================================

resource "aws_security_group" "vault_server_lb" {
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

    dynamic "ingress" {
        for_each = merge(
            var.app_allow_campus ? var.campus_cidrs : {},
            var.app_allow_cidrs,
        )

        content {
            description = "Vault application (${ingress.key})"

            protocol  = "tcp"
            from_port = 443
            to_port   = 443

            cidr_blocks = ingress.value
        }
    }

    egress {
        protocol  = "-1"
        from_port = 0
        to_port   = 0

        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags = {
        Name        = "${var.project}-lb"
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_lb" "vault_server" {
    count = var.vault_server_fqdn == null ? 0 : 1

    name_prefix        = "vault-"
    load_balancer_type = "application"

    subnets = data.aws_subnet.public[*].id
    security_groups = [
        aws_security_group.vault_server_lb.id,
    ]
    internal = false

    tags = {
        Name        = var.vault_server_fqdn
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_lb_target_group" "vault_server" {
    count = var.vault_server_fqdn == null ? 0 : 1

    name_prefix = "vault-"
    vpc_id      = data.aws_vpc.public.id

    port        = 8220
    protocol    = "HTTPS"
    target_type = "instance"
    slow_start  = 30

    health_check {
        interval = 30
        timeout  = 10

        port     = 8200
        protocol = "HTTPS"

        path    = "/v1/sys/health"
        matcher = "200,429"
    }

    tags = {
        Name        = var.vault_server_fqdn
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_lb_target_group_attachment" "vault_server" {
    count = var.vault_server_fqdn == null ? 0 : length(data.aws_subnet.public)

    target_group_arn = aws_lb_target_group.vault_server[0].arn
    target_id        = aws_instance.vault_server[count.index].id
}

resource "aws_lb_listener" "vault_server" {
    count = var.vault_server_fqdn == null ? 0 : 1

    load_balancer_arn = aws_lb.vault_server[0].arn

    port            = 8200
    protocol        = "HTTPS"
    ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
    certificate_arn = data.aws_acm_certificate.vault_server[0].arn

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.vault_server[0].arn
    }
}

resource "aws_lb_listener" "vault_server_443" {
    count = var.vault_server_fqdn == null ? 0 : 1

    load_balancer_arn = aws_lb.vault_server[0].arn

    port            = 443
    protocol        = "HTTPS"
    ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
    certificate_arn = data.aws_acm_certificate.vault_server[0].arn

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.vault_server[0].arn
    }
}
