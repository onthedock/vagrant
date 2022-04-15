#!/usr/bin/env bash
EXIT_CODE_OK=0

argocdVersion='v2.3.3'
argocdURL="https://raw.githubusercontent.com/argoproj/argo-cd/${argocdVersion}/manifests/install.yaml"
argocdLocalInstallManifest="argocd-install-stable-${argocdVersion}.yaml"

# Descarga local de la versión estable del fichero de instalación
if [[ -e ${argocdLocalInstallManifest} ]]
then
    echo "File ${argocdLocalInstallManifest} already exists"
else
    wget --output-document ${argocdLocalInstallManifest} ${argocdURL}
fi

if [[ -z $KUBECONFIG ]]
then
    echo "\$KUBECONFIG must be defined"
    exit 1
fi

# Create namespace if it does not exists
kubectl get namespace argocd
if [[ $? -eq $EXIT_CODE_OK ]]
then
    echo "[INFO] Namespace 'argocd' already exists"
else
    kubectl create namespace argocd
fi

kubectl apply -n argocd -f ${argocdLocalInstallManifest}

# Wait until it is running

readyReplicas=$(kubectl -n argocd get deploy argocd-server -o jsonpath='{.status.readyReplicas}')

t=0
until [[ $readyReplicas -eq 1 ]]
do
    printf "[INFO] Waiting for ArgoCD deployment to be ready (time elapsed %d seconds) ...\n" "$t"
    readyReplicas=$(kubectl -n argocd get deploy argocd-server -o jsonpath='{.status.readyReplicas}')
    sleep 10
    t=$((t+10))
done

echo "[INFO] ArgoCD server deployed."

echo "[INFO] Configuring insecure access (using ConfigMap)..."

cat <<- EOF > argocd-cmd-params-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  ## Server properties
  # Run server without TLS
  server.insecure: "true"
EOF

kubectl apply -f argocd-cmd-params-cm.yaml
rm argocd-cmd-params-cm.yaml
kubectl -n argocd rollout restart deploy argocd-server

echo "[INFO] Deploy Ingress (argocd.dev.lab)"

cat <<- EOF > argocd-ingress-traefik.yaml
---
apiVersion: networking.k8s.io/v1 # Kubernetes 1.19+
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    kubernets.io/ingress.class: traefik
  name: argocd
  namespace: argocd
spec:
  rules:
  - host: "argocd.dev.lab"
    http:
      paths:
        - path: "/"
          pathType: Prefix
          backend:
            service:
              name: argocd-server
              port:
                number: 80
EOF

kubectl apply -f argocd-ingress-traefik.yaml
rm argocd-ingress-traefik.yaml