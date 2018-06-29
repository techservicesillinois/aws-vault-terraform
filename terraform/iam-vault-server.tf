# =========================================================
# Data
# =========================================================


# =========================================================
# Resources
# =========================================================

resource "aws_iam_instance_profile" "vault_server" {
    name_prefix = "${var.project}-server-"
    path = "/${var.project}/server/"
    role = "${aws_iam_role.vault_server.name}"
}

resource "aws_iam_role" "vault_server" {
    name_prefix = "${var.project}-server-"
    path = "/${var.project}/server/"
    description = "ECS ${var.project} server instance role"

    assume_role_policy = "${data.aws_iam_policy_document.instance_assume_role.json}"
}

# Base required roles for any ECS Cluster Instance that logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "vault_server_AmazonEC2ContainerServiceforEC2Role" {
    role = "${aws_iam_role.vault_server.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"

    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_iam_role_policy_attachment" "vault_server_instance_logs" {
    role = "${aws_iam_role.vault_server.name}"
    policy_arn = "${aws_iam_policy.instance_logs.arn}"

    lifecycle {
        create_before_destroy = true
    }
}
