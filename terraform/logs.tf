# ===================================================================
# Resources
# ===================================================================

resource "aws_cloudwatch_log_group" "instance_logs_audit" {
    name              = "/${var.project}/ec2-instances/var/log/audit/audit.log"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_boot" {
    name              = "/${var.project}/ec2-instances/var/log/boot.log"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_cloudinit" {
    name              = "/${var.project}/ec2-instances/var/log/cloud-init.log"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_cron" {
    name              = "/${var.project}/ec2-instances/var/log/cron"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_ecsaudit" {
    name              = "/${var.project}/ec2-instances/var/log/ecs/audit.log"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_ecsagent" {
    name              = "/${var.project}/ec2-instances/var/log/ecs/ecs-agent.log"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_ecsinit" {
    name              = "/${var.project}/ec2-instances/var/log/ecs/ecs-init.log"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_messages" {
    name              = "/${var.project}/ec2-instances/var/log/messages"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}

resource "aws_cloudwatch_log_group" "instance_logs_secure" {
    name              = "/${var.project}/ec2-instances/var/log/secure"
    retention_in_days = lower(var.environment) == "production" ? 30 : 7

    kms_key_id = aws_kms_key.vault.arn

    tags = {
        Service            = var.service
        Contact            = var.contact
        DataClassification = var.data_classification
        Environment        = var.environment
        Project            = var.project
        NetID              = var.contact
    }
}
