[
    {
        "name": "vault-server",
        "image": "${server_image}",
        "essential": true,

        "command": [ "vault", "server", "-config=/vault/config/config.hcl" ],
        "environment": [
            { "name": "AWS_REGION", "value": "${region}" },
            { "name": "AWS_DEFAULT_REGION", "value": "${region}" },
            { "name": "VAULT_LOG_LEVEL", "value": "${log_level}" }
        ],
        "mountPoints": [
            { "sourceVolume": "vault-config", "containerPath": "/vault/config", "readOnly": false },
            { "sourceVolume": "vault-logs", "containerPath": "/vault/logs", "readOnly": false }
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
            { "protocol": "tcp", "containerPort": 8201, "hostPort": 8201 },
            { "protocol": "tcp", "containerPort": 8220, "hostPort": 8220 }
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
    }
]
