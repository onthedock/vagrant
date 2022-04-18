#!/usr/bin/env bash

function getKubeconfig {
    scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
    if test -f "kubeconfig"; then
        printf "[INFO] Using %s/kubeconfig\n" "$scriptDir"
        export KUBECONFIG=$scriptDir/kubeconfig
    elif test -f "$HOME"/.kube/config; then
        printf "[INFO] Using default kubeconfig at %s/.kube/config\n" "$HOME"
    elif [[ -z "$KUBECONFIG" ]]; then
        echo "[ERROR] Unable to find a valid kubeconfig"
        exit 1
    else
        printf "[INFO] Using \$KUBECONFIG=%s\n" "$KUBECONFIG"
    fi
}

function create_gitea_namespace {
    local gitea_namespace
    gitea_namespace="$1"
    cat >gitea_namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
    name: ${gitea_namespace}
EOF
    kubectl apply -f gitea_namespace.yaml
}

function create_gitea_admin_secret {
    local gitea_admin_username
    local gitea_admin_password
    local gitea_admin_default_password
    local gitea_admin_secret_name
    local gitea_namespace
    gitea_admin_default_password='tempPassword'

    gitea_admin_username="$1"
    gitea_admin_password="$gitea_admin_default_password"
    gitea_admin_secret_name="$2"
    gitea_namespace="$3"

    kubectl get secret "$gitea_admin_secret_name" --namespace "$gitea_namespace" 2>/dev/null
    if [ $? -eq 0 ]; then
        printf "[INFO] Secret %s already exists in namespace %s ...\n" "$gitea_admin_secret_name" "$gitea_namespace"
        printf "\t(using existing values for Gitea Admin username and password)\n"
        gitea_admin_username=$(kubectl get secret "$gitea_admin_secret_name" --namespace "$gitea_namespace" -o jsonpath='{.data.username}' | base64 --decode)
        gitea_admin_password=$(kubectl get secret "$gitea_admin_secret_name" --namespace "$gitea_namespace" -o jsonpath='{.data.password}' | base64 --decode)
    fi

    cat >gitea_admin_secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
    name: ${gitea_admin_secret_name}
type: Opaque
stringData:
    username: ${gitea_admin_username}
    password: ${gitea_admin_password}
EOF
    printf "[INFO] Secret %s updated in namespace %s\n" "$gitea_admin_secret_name" "$gitea_namespace"
    kubectl apply --namespace "$gitea_namespace" -f gitea_admin_secret.yaml
    rm gitea_admin_secret.yaml
}

function installHelmChart {
    helmChart="$1"
    helmRepoChart="$2"
    chartNamespace="$3"
    customValuesFile="$4"

    checkRelease=$(helm status "$helmChart" --namespace "$chartNamespace" 2>/dev/null | grep -i status | awk '{ print $2 }')

    if [ "$checkRelease" != "deployed" ]; then
        printf "[INFO] Installing %s (using Helm)...\n" "$helmChart"
        local cmd
        cmd=''
        if [[ -n "$chartNamespace" ]]; then
            cmd='--create-namespace'
        fi

        if [[ -n "$customValuesFile" ]]; then
            cmd="$cmd --values $customValuesFile"
        fi
        helm install "$helmChart" "$helmRepoChart" --namespace "$chartNamespace" $cmd
    else
        printf "[INFO] %s is already installed in the namespace %s\n" "$helmChart" "$chartNamespace"
    fi
}

function waitForGiteaToBeReady {
    helmChart="$1"
    chartNamespace="$2"
    t=0
    timeToWait=5
    result=$(kubectl get pods -n "$chartNamespace" -l app="$helmChart" -o jsonpath='{.items[].status.containerStatuses[].ready}' 2>/dev/null)
    while [[ "$result" != "true" ]]; do
        printf "Waiting for %s to be ready (time elapsed %d seconds) ...\n" "$helmChart" "$t"
        sleep "$timeToWait"
        t=$((t + timeToWait))
        result=$(kubectl get pods -n "$chartNamespace" -l app="$helmChart" -o jsonpath='{.items[].status.containerStatuses[].ready}')
    done
    printf "[INFO] %s is ready\n" "$helmChart"
}

function check_user {
    local user="$1"
    userExists=$(curl -s -H "$HEADERS" -k "$GITEA_API_URL/admin/users" -u "$admpsswd" | jq -r '.[].login' | grep -i "$user")
    if [[ "$userExists" == "$user" ]]; then
        echo 'true'
    else
        echo 'false'
    fi
}

function createNonAdminUser {
    local non_admin_user
    local admpsswd
    local payload
    non_admin_user="$1"

    admpsswd='gitea_admin:b65f599ef1015e93c2f7286c5eef7469465eb1ba'

    cat >payload.json <<EOF
        {
            "email": "${non_admin_user}@dev.lab",
            "username": "${non_admin_user}",
            "password": "gitea",
            "must_change_password": true
        }
EOF
    payload=$(cat payload.json)
    rm payload.json
    if [[ $(check_user "$non_admin_user") != 'true' ]]; then
        printf "[INFO] Creating user %s in Gitea ...\n" "$non_admin_user"
        curl -s -X POST -H "$HEADERS" -k -d "$payload" -u "$admpsswd" "$GITEA_API_URL/admin/users" | jq
    else
        printf "[INFO] %s already exists in Gitea\n" "$non_admin_user"
    fi
}

GITEA_API_URL='http://gitea.dev.lab/api/v1'
HEADERS='Content-Type: application/json'

function validate_gitea_credentials {
    local current_gitea_username
    local current_gitea_password
    local retries
    current_gitea_username="$1"
    current_gitea_password="$2"
    retries=0

    response_code=$(curl -o /dev/null -s -w "%{http_code}" -H "$HEADERS" -u "$current_gitea_username:$current_gitea_password" "$GITEA_API_URL/admin/users")
    while [[ "$retries" -lt 3 ]]; do
        sleep 1
        retries=$((retries + 1))
        response_code=$(curl -o /dev/null -s -w "%{http_code}" -H "$HEADERS" -u "$current_gitea_username:$current_gitea_password" "$GITEA_API_URL/admin/users")
        if [[ "$response_code" -eq 200 ]]; then    
            break
        fi
    done
    if [[ "$response_code" -eq 200 ]]; then
        echo 'ok'
    else
        echo 'ko'
    fi
}

function update_gitea_admin_password {
    # Only update the secret if it has been updated in Gitea
    local gitea_admin_secret
    local gitea_namespace
    local current_gitea_username
    local current_gitea_password
    gitea_admin_secret="$1"
    gitea_namespace="$2"

    current_gitea_username=$(kubectl get secret "$gitea_admin_secret" --namespace "$gitea_namespace" -o jsonpath="{.data.username}" | base64 --decode)
    current_gitea_password=$(kubectl get secret "$gitea_admin_secret" --namespace "$gitea_namespace" -o jsonpath="{.data.password}" | base64 --decode)

    if [[ $(validate_gitea_credentials "$current_gitea_username" "$current_gitea_password") == 'ok' ]]; then
        printf "[PLAN] Change credentials on GITEA\n"
        new_password=$(openssl rand -hex 15)
        payload=$(cat <<-EOF
            {
                "admin": true,
                "password": "$new_password",
                "login_name": "$current_gitea_username"
            }
EOF
        )
        response=$(curl -s -w "%{http_code}" -o /dev/null -X PATCH -H "$HEADERS" -k -u "$current_gitea_username:$current_gitea_password" -d "$payload" "$GITEA_API_URL/admin/users/$current_gitea_username")
        if [[ "$response" -eq '200' ]]; then
            printf "[INFO] Credentials for %s updated in Gitea...\n" "$current_gitea_username"
            printf "\tCreating a backup of previous credentials...\n"
            kubectl patch secret "$gitea_admin_secret" --namespace "$gitea_namespace" --patch "{\"stringData\": { \"backup.password\": \"$current_gitea_password\", \"backup.created\": \"'$(date +%FT%T%Z)'\" }}"
            printf "\tUpdating the %s in the %s...\n" "$gitea_admin_secret" "$gitea_namespace"
            kubectl patch secret "$gitea_admin_secret" --namespace "$gitea_namespace" --patch "{\"stringData\": { \"password\": \"$new_password\"}}"
        fi
    else
        printf "[ERROR] Invalid credentials\n"
    fi
}


function main {
    getKubeconfig

    GITEA_NAMESPACE='gitea'
    GITEA_ADMIN_NAME='gitea_admin'
    GITEA_SECRET_NAME='gitea-admin-secret'
    GITEA_HELM_RELEASE='gitea'

    # Those commands are idempotent
    helm repo add gitea-charts https://dl.gitea.io/charts/
    helm repo update

    create_gitea_namespace "$GITEA_NAMESPACE"
    create_gitea_admin_secret "$GITEA_ADMIN_NAME" "$GITEA_SECRET_NAME" "$GITEA_NAMESPACE"
    installHelmChart "$GITEA_HELM_RELEASE" "gitea-charts/gitea" "$GITEA_NAMESPACE" "gitea_custom_values.yaml"
    waitForGiteaToBeReady "$GITEA_HELM_RELEASE" "$GITEA_NAMESPACE"
    update_gitea_admin_password "$GITEA_SECRET_NAME" "$GITEA_NAMESPACE"
    # createNonAdminUser "xavi"
}

# ----------------
main
