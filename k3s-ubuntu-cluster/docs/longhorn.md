# Longhorn

Desplegamos Longhorn usando la Helm chart oficial (sin ninguna personalización). Para ello, añadimos el repositorio y actualizamos:

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

Antes de lanzar la instalación comprobamos si la *chart* ya se ha desplegado; si no existe, se instala. El *script* no actualiza la *chart* si ya está desplegada en el clúster.

Mediante `--create-namespace`, Helm crea el *namespace* `longhorn-system` si no existe previamente en el clúster.

```bash
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
```

El despliegue de Longhorn genera la *StorageClass* `longhorn`; para establecerla como *StorageClass* por defecto en el clúster, esperamos a que se haya completado el despliegue.

```bash
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
```

Entonces modificamos el valor de las anotaciones de todas las *StorageClass* existentes para establecer `longhorn` como *StorageClass* por defecto en el clúster:

```bash
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
```
