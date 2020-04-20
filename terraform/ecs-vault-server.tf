# =========================================================
# Locals
# =========================================================

locals {
    vault_server_image = "${replace(var.vault_server_image, "/^(.+?)(:[^:]+)?$/", "$1")}@${data.docker_registry_image.vault_server.sha256_digest}"
    vault_helper_image = "${replace(var.vault_helper_image, "/^(.+?)(:[^:]+)?$/", "$1")}@${data.docker_registry_image.vault_helper.sha256_digest}"
}

# =========================================================
# Data
# =========================================================

data "docker_registry_image" "vault_server" {
    name = var.vault_server_image
}

data "docker_registry_image" "vault_helper" {
    name = var.vault_helper_image
}

data "template_file" "vault_init_containers" {
    template = file("${path.module}/templates/ecs-tasks/vault-init.json.tpl")

    vars = {
        project = var.project
        region  = data.aws_region.current.name

        log_group               = aws_cloudwatch_log_group.vault_server_containers.name
        helper_image            = local.vault_helper_image
        helper_command          = join(", ", formatlist("\"%s\"", concat(["init"], var.vault_server_admin_groups)))
        helper_ldapcreds_bucket = var.deploy_bucket
        helper_ldapcreds_object = "${var.deploy_prefix}ldap-credentials.txt"
        helper_master_secret    = aws_secretsmanager_secret.vault_master.name
        helper_recovery_secret  = aws_secretsmanager_secret.vault_recovery.name
    }
}

data "template_file" "vault_server_containers" {
    template = file("${path.module}/templates/ecs-tasks/vault-server.json.tpl")

    vars = {
        project = var.project
        region  = data.aws_region.current.name

        log_group    = aws_cloudwatch_log_group.vault_server_containers.name
        log_level    = lookup(var.log_levels, var.environment, "info")
        server_image = local.vault_server_image
        server_mem = lookup(
            var.docker_instance2memoryres,
            var.vault_server_instance_type,
            floor(var.docker_instance2memory[var.vault_server_instance_type] / 2),
        )
        server_cpu = var.docker_instance2cpu[var.vault_server_instance_type]
    }
}

# =========================================================
# Resources
# =========================================================

resource "aws_ecs_cluster" "vault_server" {
    name = "${var.project}-server"
}

resource "aws_ecs_service" "vault_server" {
    depends_on = [
        aws_dynamodb_table.vault_storage,
        null_resource.vault_server_ansible,
        null_resource.wait_vault_server_task_role,
    ]

    name            = "Server"
    cluster         = aws_ecs_cluster.vault_server.arn
    task_definition = aws_ecs_task_definition.vault_server.arn

    launch_type         = "EC2"
    scheduling_strategy = "DAEMON"
}

resource "null_resource" "vault_server_init" {
    depends_on = [
        aws_ecs_service.vault_server,
        null_resource.wait_vault_init_task_role,
    ]

    provisioner "local-exec" {
        command     = "./scripts/vault-server-init.sh"
        working_dir = path.module

        environment = {
            UIUC_VAULT_CLUSTER   = aws_ecs_cluster.vault_server.name
            UIUC_VAULT_INIT_TASK = aws_ecs_task_definition.vault_init.arn
            AWS_DEFAULT_REGION   = data.aws_region.current.name
        }
    }
}

resource "aws_ecs_task_definition" "vault_init" {
    family                = "${var.project}-init"
    container_definitions = data.template_file.vault_init_containers.rendered

    task_role_arn      = aws_iam_role.vault_init_task.arn
    execution_role_arn = data.aws_iam_role.task_execution.arn

    network_mode             = "bridge"
    requires_compatibilities = [ "EC2" ]

    volume {
        name      = "docker-bin"
        host_path = "/usr/bin/docker"
    }
    volume {
        name      = "docker-cgroup"
        host_path = "/cgroup"
    }
    volume {
        name      = "docker-plugins-etc"
        host_path = "/etc/docker/plugins"
    }
    volume {
        name      = "docker-plugins-lib"
        host_path = "/usr/lib/docker/plugins"
    }
    volume {
        name      = "docker-plugins-run"
        host_path = "/run/docker/plugins"
    }
    volume {
        name      = "docker-proc"
        host_path = "/proc"
    }
    volume {
        name      = "docker-sock"
        host_path = "/var/run/docker.sock"
    }
}

resource "aws_ecs_task_definition" "vault_server" {
    family                = "${var.project}-server"
    container_definitions = data.template_file.vault_server_containers.rendered

    task_role_arn      = aws_iam_role.vault_server_task.arn
    execution_role_arn = data.aws_iam_role.task_execution.arn

    network_mode             = "bridge"
    requires_compatibilities = [ "EC2" ]

    volume {
        name      = "vault-config"
        host_path = "/vault/config"
    }
    volume {
        name      = "vault-logs"
        host_path = "/vault/logs"
    }

    volume {
        name      = "docker-bin"
        host_path = "/usr/bin/docker"
    }
    volume {
        name      = "docker-cgroup"
        host_path = "/cgroup"
    }
    volume {
        name      = "docker-plugins-etc"
        host_path = "/etc/docker/plugins"
    }
    volume {
        name      = "docker-plugins-lib"
        host_path = "/usr/lib/docker/plugins"
    }
    volume {
        name      = "docker-plugins-run"
        host_path = "/run/docker/plugins"
    }
    volume {
        name      = "docker-proc"
        host_path = "/proc"
    }
    volume {
        name      = "docker-sock"
        host_path = "/var/run/docker.sock"
    }
}
