[
    {
        "name": "vault-server",
        "image": "${server_image}",
        "essential": true,

        "command": [ "vault", "server", "-config=/vault/config/config.hcl" ],
        "environment": [
            { "name": "AWS_REGION", "value": "${region}" },
            { "name": "AWS_DEFAULT_REGION", "value": "${region}" }
        ],
        "mountPoints": [
            { "sourceVolume": "vault-config", "containerPath": "/vault/config", "readOnly": false }
        ],
        "dockerLabels": {
            "edu.illinois.ics.vault.role": "server"
        },
        "linuxParameters": {
            "capabilities": {
                "add": [ "IPC_LOCK" ]
            }
        },

        "memoryReservation": ${server_mem},
        "cpu": ${server_cpu},

        "portMappings": [
            { "protocol": "tcp", "containerPort": 8200, "hostPort": 8200 },
            { "protocol": "tcp", "containerPort": 8201, "hostPort": 8201 }
        ],

        "healthCheck": {
            "command": [ "CMD-SHELL", "case \"$(wget --spider -S \"http://localhost:8100/v1/sys/health\" 2>&1 | sed -rn -e 's#^[[:space:]]*HTTP/[[:digit:]]+([.][[:digit:]]+)?[[:space:]]+([[:digit:]]+).*$#\\2# p')\" in 200|429|472|501|503) exit 0 ;; *) exit 1 ;; esac" ],
            "interval": 30,
            "timeout": 10,
            "retries": 3,
            "startPeriod": 30
        },

        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-region": "${region}",
                "awslogs-group": "${log_group}",
                "awslogs-stream-prefix": "${project}"
            }
        }
    },
    {
        "name": "vault-helper-unseal",
        "image": "${helper_image}",
        "essential": false,

        "command": [ "unseal" ],
        "environment": [
            { "name": "AWS_REGION", "value": "${region}" },
            { "name": "AWS_DEFAULT_REGION", "value": "${region}" },
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
            "edu.illinois.ics.vault.role": "helper-unseal"
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
