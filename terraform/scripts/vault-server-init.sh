#!/bin/bash

set -e

echoerr () { echo "$@" 1>&2; }

if [[ -z $UIUC_VAULT_CLUSTER ]]; then
    echoerr "ERROR: no UIUC_VAULT_CLUSTER specified."
    exit 1
fi
if [[ -z $UIUC_VAULT_INIT_TASK ]]; then
    echoerr "ERROR: no UIUC_VAULT_INIT_TASK specified."
    exit 1
fi

echo "INFO: launching vault-server init task"
task_arn="$(aws ecs run-task \
    --cluster "$UIUC_VAULT_CLUSTER" \
    --task-definition "$UIUC_VAULT_INIT_TASK" \
    --count 1 \
    --launch-type EC2 \
    --query 'tasks[0].taskArn' | tr -d '"'
)"
if [[ -z $task_arn || $task_arn == "null" ]]; then
    echoerr "ERROR: unable to launch the init task"
    exit 2
fi

echo "INFO: waiting for vault-server init task ($task_arn) to stop"
aws ecs wait tasks-stopped \
    --cluster "$UIUC_VAULT_CLUSTER" \
    --tasks "$task_arn"
