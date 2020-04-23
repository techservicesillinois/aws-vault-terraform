#cloud-boothook

set -e

write_file () {
    local file="$1"
    local path="$(dirname "$file")"

    local filemod="$${2:-0644}"
    local fileown="$${3:-root:root}"

    [[ -e $path ]] || mkdir -p "$path"
    cat > "$file"

    chmod "$filemod" "$file"
    chown "$fileown" "$file"
}

write_file /etc/opt/illinois/cloud-init/cis.conf <<EOF
ip_forward=1
ssh_allow_groups='${ssh_allow_groups}'
EOF

write_file /etc/opt/illinois/cloud-init/ecslogs.conf <<EOF
loggroup_prefix='/${project}/ec2-instances'
metrics_collection_interval=${metrics_collection_interval}
net_resources=eth0
EOF

write_file /etc/opt/illinois/cloud-init/sss.conf <<EOF
sss_allow_groups='${sss_allow_groups}'
sss_bindcreds_bucket='${sss_bindcreds_bucket}'
sss_bindcreds_object='${sss_bindcreds_object}'
EOF

write_file /etc/ecs/ecs.config <<EOF
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_ENABLE_TASK_ENI=true
ECS_ENABLE_CONTAINER_METADATA=true
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","syslog","awslogs","splunk"]
EOF

write_file /etc/security/limits.d/uiuc-vault <<EOF
*       soft    nofile      1024
*       hard    nofile      65536
*       hard    core        0
EOF

write_file /etc/sysconfig/docker <<EOF
# The max number of open files for the daemon itself, and all
# running containers.  The default value of 1048576 mirrors the value
# used by the systemd service unit.
DAEMON_MAXFILES=1048576

# Additional startup options for the Docker daemon, for example:",
# OPTIONS=\"--ip-forward=true --iptables=true\"",
# By default we limit the number of open files per container",
OPTIONS="--default-ulimit nofile=1024:4096 --bip=172.24.0.1/16 --fixed-cidr=172.24.128.0/17"
EOF
