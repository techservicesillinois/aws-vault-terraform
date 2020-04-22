#!/bin/bash

set -e

# LDAP server to connect to for Vault authentication.
#
# Default: ldap-ad-aws.ldap.illinois.edu
: ${UIUC_VAULT_LDAP_HOST:=ldap-ad-aws.ldap.illinois.edu}

# Don't check the SSL certificate on the LDAP server. This can be
# useful for testing but shouldn't appear in production.
#
# Default: false (check the cert)
: ${UIUC_VAULT_LDAP_INSECURE:=false}

echoerr () { echo "$@" 1>&2; }

# Finish handler run at the helper exit. This looks at the `root_tokens`
# array and revokes each of them.
root_tokens=()
finish () {
    # Cleanup all root tokens we allocated
    for token in "${root_tokens[@]}"; do
        VAULT_TOKEN="$token"
        vault token revoke -self || :

        echoerr "INFO: revoked root token $token"
    done
}
trap finish EXIT

# Run a vault command, but in the vault-server container running on
# this host. This uses the first container ID with the label
# `edu.illinois.ics.vault.role=server`. If it can't find a container
# with that label then it sleeps 1s and tries again.
#
# You will need to set `VAULT_TOKEN` before running this. All output
# is JSON formatted, with the newlines stripped (helps with logging).
# Return value is the exit code of the command.
vault () {
    # List running containers with the server role, placing the ID's in
    # the `_container_id` array. Stop when we get at least one.
    declare -a _container_id
    while [[ ${#_container_id[@]} -le 0 ]]; do
        _container_id=($(docker ps --filter "label=edu.illinois.ics.vault.role=server" --format '{{.ID}}'))

        if [[ ${#_container_id[@]} -le 0 ]]; then
            sleep 1
            echoerr "Waiting for vault-server docker container"
        fi
    done

    docker exec -i \
        -e "VAULT_ADDR=$VAULT_ADDR" \
        -e "VAULT_TOKEN=$VAULT_TOKEN" \
        -e VAULT_FORMAT=json \
        "${_container_id[0]}" \
        vault "$@" | tr '\n' ' '
    local _vault_status=${PIPESTATUS[0]}

    # Add a trailing newline since we stripped them all off
    echo ""
    return $_vault_status
}

# Get the status on stdout. This disables error checking so that a
# status check does not exit the script. The values are:
#
# - unsealed
# - sealed
# - error
#
# Any output is redirected to stderr instead of stdout.
uiuc_vault_status () {
    local _status_result _status_sealed _status_initialized

    # Turn off error checking when running the status command.
    set +e
    _status_result=$(vault status)
    set -e

    _status_sealed=$(jq -r '.sealed' <<< "$_status_result")
    _status_initialized=$(jq -r '.initialized' <<< "$_status_result")

    if [[ $_status_initialized = 'false' ]]; then
        echo "uninitialized"
    elif [[ $_status_initialized = 'true' && $_status_sealed = 'true' ]]; then
        echo "sealed"
    elif [[ $_status_initialized = 'true' && $_status_sealed = 'false' ]]; then
        echo "unsealed"
    else
        echo "error"
    fi
}

# Initialize the vault-server. It does this by following this process:
#
# - read the LDAP query secret
# - run vault operator init
# - unseal the vault
# - store the generated master keys
# - create an admin policy with all permissions
# - enable and configure LDAP auth
# - for each admin group set the admin policy
# - enable AWS auth
#
# The root key returned by the init operation will be revoked when the
# script exits.
uiuc_vault_init () {
    local _init_result _init_masterkeys _init_recoverykeys
    local _status _result
    local _ldap_accessor

    if [[ -z $UIUC_VAULT_MASTER_SECRET ]]; then
        echoerr "ERROR: no UIUC_VAULT_MASTER_SECRET specified"
        return 1
    fi
    if [[ -z $UIUC_VAULT_RECOVERY_SECRET ]]; then
        echoerr "ERROR: no UIUC_VAULT_RECOVERY_SECRET specified"
        return 1
    fi
    if [[ -z $UIUC_VAULT_LDAPCREDS_BUCKET ]]; then
        echoerr "ERROR: no UIUC_VAULT_LDAPCREDS_BUCKET specified"
        return 1
    fi
    if [[ -z $UIUC_VAULT_LDAPCREDS_OBJECT ]]; then
        echoerr "ERROR: no UIUC_VAULT_LDAPCREDS_OBJECT specified"
        return 1
    fi
    if [[ $# -le 0 ]]; then
        echoerr "ERROR: no admins specified"
        return 1
    fi

    _result="$(aws s3 cp "s3://$UIUC_VAULT_LDAPCREDS_BUCKET/$UIUC_VAULT_LDAPCREDS_OBJECT" - | tr -d '\r')"
    if [[ -z $_result ]]; then
        echoerr "ERROR: empty value for s3://$UIUC_VAULT_LDAPCREDS_BUCKET/$UIUC_VAULT_LDAPCREDS_OBJECT"
        return 1
    fi
    declare -a _ldap_secret; readarray -t _ldap_secret <<< "$_result"

    _status=$(uiuc_vault_status)
    if [[ $_status == "sealed" || $_status == "unsealed" ]]; then
        echoerr "INFO: vault-server is already initialized"
        return 0
    fi

    _init_result="$(vault operator init -recovery-shares=5 -recovery-threshold=3)"

    _init_masterkeys="$(jq '{ unseal_keys_b64: .unseal_keys_b64, unseal_keys_hex: .unseal_keys_hex }' <<< "$_init_result")"
    aws secretsmanager put-secret-value \
        --secret-id "$UIUC_VAULT_MASTER_SECRET" \
        --secret-string "${_init_masterkeys@E}" \
        --version-stages AWSCURRENT

    _init_recoverykeys="$(jq '{ recovery_keys_b64: .recovery_keys_b64, recovery_keys_hex: .recovery_keys_hex }' <<< "$_init_result")"
    aws secretsmanager put-secret-value \
        --secret-id "$UIUC_VAULT_RECOVERY_SECRET" \
        --secret-string "${_init_recoverykeys@E}" \
        --version-stages AWSCURRENT

    VAULT_TOKEN="$(jq -r '.root_token' <<< "$_init_result")"
    root_tokens+=("$VAULT_TOKEN")

    echoerr "INFO: enable auditing (stdout)"
    vault audit enable -path="stdout/" file \
        file_path=stdout \
        format=json \
        prefix="AUDIT: "

    echoerr "INFO: enable auditing (file)"
    vault audit enable -path="file/" file \
        file_path=/vault/logs/audit.log \
        format=json

    echoerr "INFO: creating the admin policy"
    vault policy write admin - <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

    echoerr "INFO: enabling ldap auth"
    vault auth enable -listing-visibility=unauth ldap
    _ldap_accessor="$(vault auth list | jq -r '."ldap/".accessor')"

    echoerr "INFO: configuring ldap auth"
    vault write auth/ldap/config \
        url="ldap://$UIUC_VAULT_LDAP_HOST" \
        starttls=true \
        insecure_tls="$UIUC_VAULT_LDAP_INSECURE" \
        certificate=@/vault/config/ldap-ca.crt \
        binddn="${_ldap_secret[0]@E}" \
        bindpass="${_ldap_secret[1]@E}" \
        userdn='DC=ad,DC=uillinois,DC=edu' \
        userattr=sAMAccountName \
        use_token_groups=true

    for group in "$@"; do
        echo "INFO: adding admin policy for $group"
        _result="$(vault write identity/group \
            name="$group" \
            type=external \
            policies=admin
        )"
        vault write identity/group-alias \
            name="$group" \
            canonical_id="$(jq -r '.data.id' <<< "$_result")" \
            mount_accessor="$_ldap_accessor"
    done

    echoerr "INFO: enabling aws auth"
    vault auth enable aws
}

cmd="$1"; shift
case "$cmd" in
    init)           uiuc_vault_init "$@";;
    *)              exec "$cmd" "$@"
esac
