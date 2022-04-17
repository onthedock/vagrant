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
        helm install $helmChart $helmRepoChart --namespace $chartNamespace $cmd
    else
        printf "[INFO] %s is already installed in the namespace %s\n" "$helmChart" "$chartNamespace"
    fi
}

# kubectl get $(kubectl get pods -n gitea -l app=gitea -o name) -n gitea -o json | jq '.status.containerStatuses[0].ready'
# kubectl get $(kubectl get pods -n gitea -l app=gitea -o name) -n gitea -o jsonpath='.status.containerStatuses[0].ready' 

function waitForGiteaToBeReady {
    helmChart="$1"
    chartNamespace="$2"
    t=0
    timeToWait=5
    result=$(kubectl get pods -n $chartNamespace -l app=$helmChart -o jsonpath='{.items[].status.containerStatuses[].ready}')
    while [[ "$result" != "true" ]]
    do
        printf "Waiting for %s to be ready (time elapsed %d seconds) ...\n" "$helmChart" "$t"
        sleep "$timeToWait"
        t=$((t+timeToWait))
        result=$(kubectl get pods -n $chartNamespace -l app=$helmChart -o jsonpath='{.items[].status.containerStatuses[].ready}')
    done
    printf "[INFO] is %s ready" "$helmChart"
}

function main {
    getKubeconfig

    # Those commands are idempotent
    helm repo add gitea-charts https://dl.gitea.io/charts/
    helm repo update

    installHelmChart "gitea" "gitea-charts/gitea" "gitea" "gitea_custom_values.yaml"
    waitForGiteaToBeReady "gitea" "gitea"
}

main
