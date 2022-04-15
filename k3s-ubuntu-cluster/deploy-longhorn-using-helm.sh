#!/usr/bin/env bash

function getKubeconfig {
    scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
    if test -f "kubeconfig"; then
        printf "Using %s/kubeconfig\n" "$scriptDir"
        export KUBECONFIG=$scriptDir/kubeconfig
    elif test -f "$HOME"/.kube/config; then
        printf "Using default kubeconfig at %s/.kube/config\n" "$HOME"
    elif [[ -z "$KUBECONFIG" ]]; then
        echo "ERROR - Unable to find a valid kubeconfig"
        exit 1
    else
        printf "Using \$KUBECONFIG=%s\n" "$KUBECONFIG"
    fi
}

function installHelmChart {
    helmChart="$1"
    helmRepoChart="$2"
    chartNamespace="$3"

    checkRelease=$(helm status "$helmChart" --namespace "$chartNamespace" 2>/dev/null | grep -i status | awk '{ print $2 }')

    if [ "$checkRelease" != "deployed" ]; then
        echo "...Installing longhorn"
        helm install "$helmChart" "$helmRepoChart" --namespace "$chartNamespace" --create-namespace
    else
        printf "... %s is already installed in the namespace %s" "$helmChart" "$chartNamespace"
    fi
}

function waitForStorageClassToBeReady {
    local storageClass="$1"
    local timeToWait=2
    while ! (kubectl get storageclass -o name | grep "$storageClass" 1>/dev/null)
    do
        printf "Waiting for storageClass %s to be ready (check again in %s seconds) ...\n" "$storageClass" "$timeToWait"
        sleep $timeToWait
    done
    printf "storageClass %s is ready to be used\n" "$storageClass"
}

function setDefaultStorageClass {
    defaultStorageClass="$1"
    storageClassList=$(kubectl get storageclass -o name | awk -F '/' '{print $2}')

    for storageclass in $storageClassList; do
        if [ "$storageclass" = "$defaultStorageClass" ]; then
            printf "Set default storageClass for %s\n" "$storageclass"
            kubectl patch storageclass "$storageclass" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        else
            printf "Removing default storageClass for %s\n" "$storageclass"
            kubectl patch storageclass "$storageclass" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        fi
    done
}

function main {
    getKubeconfig

    # Those commands are idempotent
    helm repo add longhorn https://charts.longhorn.io
    helm repo update

    installHelmChart "longhorn" "longhorn/longhorn" "longhorn-system"
    waitForStorageClassToBeReady "longhorn"    
    setDefaultStorageClass "longhorn"
}

main
