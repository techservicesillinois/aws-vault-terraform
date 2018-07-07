#!/bin/bash

set -e

: ${UIUC_VAULT_MASTER_SECRET_MAX_TRIES:=0}
: ${UIUC_VAULT_LDAP_HOST:=ldap-ad-aws.ldap.illinois.edu}
: ${UIUC_VAULT_LDAP_INSECURE:=false}

echoerr () { echo "$@" 1>&2; }

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
# this host.
vault () {
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
    local _exitcode

    set +e
    vault status 1>&2; _exitcode=$?
    set -e

    case $_exitcode in
        0)      echo "unsealed" ;;
        2)      echo "sealed"   ;;
        *)      echo "error"    ;;
    esac
}

# Return the master keys from the secrets manager. This will loop if
# there is an error getting the secret value, until UIUC_VAULT_MASTER_SECRET_MAX_TRIES
# is up. It sleeps 60 seconds between tries.
#
# Keys are returned on STDOUT, one per line.
uiuc_master_keys () {
    if [[ -z $UIUC_VAULT_MASTER_SECRET ]]; then
        echoerr "ERROR: no UIUC_VAULT_MASTER_SECRET specified"
        return 1
    fi

    local _result='' _result_keys=''
    for (( _idx = 0; _idx < UIUC_VAULT_MASTER_SECRET_MAX_TRIES || UIUC_VAULT_MASTER_SECRET_MAX_TRIES == 0; _idx++ )); do
        _result="$(aws secretsmanager get-secret-value --secret-id "$UIUC_VAULT_MASTER_SECRET" || :)"
        _result_keys="$(jq -r '.SecretString | fromjson? | .unseal_keys_hex[]' <<< "$_result")"

        if [[ -n $_result_keys ]]; then
            echo "$_result_keys"
            return 0
        else
            echoerr "Waiting for vault-server master secret ($UIUC_VAULT_MASTER_SECRET)"
            sleep 60
        fi
    done

    echoerr "ERROR: unable to get vault-server master secret ($UIUC_VAULT_MASTER_SECRET) after $UIUC_VAULT_MASTER_SECRET_MAX_TRIES tries"
    return 1
}

# Initialize the vault-server, store the master keys, configure LDAP,
# and revoke the root key
uiuc_vault_init () {
    local _init_result _init_keys
    local _status _result

    if [[ -z $UIUC_VAULT_MASTER_SECRET ]]; then
        echoerr "ERROR: no UIUC_VAULT_MASTER_SECRET specified"
        return 1
    fi
    if [[ -z $UIUC_VAULT_LDAP_SECRET ]]; then
        echoerr "ERROR: no UIUC_VAULT_LDAP_SECRET specified"
        return 1
    fi
    if [[ $# -le 0 ]]; then
        echoerr "ERROR: no admins specified"
        return 1
    fi

    _result="$(aws secretsmanager get-secret-value --secret-id "$UIUC_VAULT_LDAP_SECRET" | jq -r '.SecretString')"
    if [[ -z $_result ]]; then
        echoerr "ERROR: empty value for $UIUC_VAULT_LDAP_SECRET secret"
        return 1
    fi
    declare -a _ldap_secret; readarray -t _ldap_secret <<< "$_result"

    _status=$(uiuc_vault_status)
    if [[ $_status == "sealed" || $_status == "unsealed" ]]; then
        echoerr "INFO: vault-server is already initialized"
        return 0
    fi

    _init_result="$(vault operator init)"

    uiuc_vault_unseal $(jq -r '.unseal_keys_hex[]' <<< "$_init_result")

    _init_keys="$(jq '{ unseal_keys_b64: .unseal_keys_b64, unseal_keys_hex: .unseal_keys_hex }' <<< "$_init_result")"
    aws secretsmanager put-secret-value \
        --secret-id "$UIUC_VAULT_MASTER_SECRET" \
        --secret-string "${_init_keys@E}" \
        --version-stages AWSCURRENT

    VAULT_TOKEN="$(jq -r '.root_token' <<< "$_init_result")"
    root_tokens+=("$VAULT_TOKEN")

    echoerr "INFO: creating the admin policy"
    vault policy write admin - <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

    echoerr "INFO: enabling ldap auth"
    vault auth enable ldap

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
        groupdn='DC=ad,DC=uillinois,DC=edu' \
        groupfilter='(&(objectClass=User)(distinguishedName={{.UserDN}}))' \
        groupattr=memberOf

    for group in "$@"; do
        echo "INFO: adding root policy for $group"
        vault write "auth/ldap/groups/$group" policies=admin
    done

    echoerr "INFO: enabling aws auth"
    vault auth enable aws
}

# Unseal the vault-server using data from the master key secret.
uiuc_vault_unseal () {
    declare -a _master_keys
    if [[ $# -gt 0 ]]; then
        _master_keys=("$@")
    else
        _master_keys=($(uiuc_master_keys))
    fi

    local _idx=0 _status=''
    while [[ $_idx -lt ${#_master_keys[@]} ]]; do
        _status=$(uiuc_vault_status)

        case $_status in
            unsealed)
                echoerr "INFO: vault-server is unsealed"
                return 0
                ;;

            error)
                echoerr "ERROR: vault-server status returned an error"
                # Reset the seal keys used and sleep for a minute
                _idx=0
                sleep 60
                ;;

            sealed)
                echoerr "INFO: unsealing vault-server with key #$_idx"
                vault operator unseal "${_master_keys[$_idx]}"
                (( _idx++ )) || :
                ;;
        esac
    done

    echoerr "ERROR: not enough keys to unseal the vault-server"
    return 1
}

cmd="$1"; shift
case "$cmd" in
    init)           uiuc_vault_init "$@";;
    unseal)         uiuc_vault_unseal "$@";;
    *)              exec "$cmd" "$@"
esac
