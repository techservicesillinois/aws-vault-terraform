[
    {
        "name": "vault-helper-init",
        "image": "${helper_image}",
        "essential": true,

        "command": [ ${helper_command} ],
        "environment": [
            { "name": "AWS_REGION", "value": "${region}" },
            { "name": "AWS_DEFAULT_REGION", "value": "${region}" },
            { "name": "UIUC_VAULT_LDAP_SECRET", "value": "${helper_ldap_secret}" },
            { "name": "UIUC_VAULT_MASTER_SECRET", "value": "${helper_master_secret}" },
            { "name": "VAULT_ADDR", "value": "http://localhost:8100" }
        ],
        "mountPoints": [
            { "sourceVolume": "docker-bin",             "containerPath": "/usr/bin/docker",         "readOnly": true },
            { "sourceVolume": "docker-cgroup",          "containerPath": "/sys/fs/cgroup",          "readOnly": false },
            { "sourceVolume": "docker-plugins-etc",     "containerPath": "/etc/docker/plugins",     "readOnly": true },
            { "sourceVolume": "docker-plugins-lib",     "containerPath": "/usr/lib/docker/pluins",  "readOnly": true },
            { "sourceVolume": "docker-plugins-run",     "containerPath": "/run/docker/plugins",     "readOnly": true },
            { "sourceVolume": "docker-proc",            "containerPath": "/host/proc",              "readOnly": true },
            { "sourceVolume": "docker-sock",            "containerPath": "/var/run/docker.sock",    "readOnly": false }
        ],
        "dockerLabels": {
            "edu.illinois.ics.vault.role": "helper-init"
        },

        "memoryReservation": 128,
        "cpu": 256,

        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-region": "${region}",
                "awslogs-group": "${log_group}",
                "awslogs-stream-prefix": "${project}"
            }
        }
    }
]
