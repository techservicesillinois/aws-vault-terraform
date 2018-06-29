# ===================================================================
# Resources
# ===================================================================

resource "aws_cloudwatch_log_group" "instance_logs_cron" {
    name = "/${var.project}/ec2-instances/var/log/cron"
    retention_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_docker" {
    name = "/${var.project}/ec2-instances/var/log/docker"
    retention_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_ecsagent" {
    name = "/${var.project}/ec2-instances/var/log/ecs/ecs-agent.log"
    retention_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_messages" {
    name = "/${var.project}/ec2-instances/var/log/messages"
    retention_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_secure" {
    name = "/${var.project}/ec2-instances/var/log/secure"
    retention_in_days = "${lower(var.environment) == "production" ? 30 : 7}"

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}
