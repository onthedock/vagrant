#!/usr/bin/env bash

getKubeconfig() {
    if [[ -z "$KUBECONFIG" ]]; then
        echo "[ERROR] Unable to find a valid kubeconfig"
        exit 1
    else
        printf "[INFO] Using \$KUBECONFIG=%s\n" "$KUBECONFIG"
    fi
}

installHelmChart() {
    helmChart="$1"
    helmRepoChart="$2"
    chartNamespace="$3"

    checkRelease=$(helm status "$helmChart" --namespace "$chartNamespace" 2>/dev/null | grep -i status | awk '{ print $2 }')

    if [ "$checkRelease" != "deployed" ]; then
        printf "[INFO] Installing %s (using Helm)...\n" "$helmChart"
        helm install "$helmChart" "$helmRepoChart" --namespace "$chartNamespace" --create-namespace
    else
        printf "[INFO] %s is already installed in the namespace %s\n" "$helmChart" "$chartNamespace"
    fi
}

waitForStorageClassToBeReady() {
    local storageClass="$1"
    local timeToWait=5
    local t=0
    while ! (kubectl get storageclass -o name | grep "$storageClass" 1>/dev/null)
    do
        printf "[INFO] Waiting for storageClass %s to be ready (time elapsed %d seconds) ...\n" "$storageClass" "$t"
        sleep $timeToWait
        t=$((t+timeToWait))
    done
    printf "[INFO] storageClass %s is ready to be used\n" "$storageClass"
}

setDefaultStorageClass() {
    defaultStorageClass="$1"
    storageClassList=$(kubectl get storageclass -o name | awk -F '/' '{print $2}')

    for storageclass in $storageClassList; do
        if [ "$storageclass" = "$defaultStorageClass" ]; then
            printf "[INFO ] Set default storageClass for %s\n" "$storageclass"
            kubectl patch storageclass "$storageclass" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        else
            printf "[INFO] Removing default storageClass for %s\n" "$storageclass"
            kubectl patch storageclass "$storageclass" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        fi
    done
}

main() {
    getKubeconfig

    # Those commands are idempotent
    helm repo add longhorn https://charts.longhorn.io
    helm repo update

    installHelmChart "longhorn" "longhorn/longhorn" "longhorn-system"
    waitForStorageClassToBeReady "longhorn"    
    setDefaultStorageClass "longhorn"
}

main
