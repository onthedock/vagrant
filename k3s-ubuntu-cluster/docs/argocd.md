# ArgoCD

La instalación de ArgoCD se realiza mediante tres *manifests*:

- el *manifest* principal que describe todos los elementos de ArgoCD
- un *ConfigMap* (aunque pueden ser varios) con configuración de usuario
- un *Ingress* que permite exponer la consola de ArgoCD *fuera* del clúster

## Despliegue de ArgoCD

Descargamos la versión indicada en el *script* del *manifest* de despliegue de los componentes de ArgoCD.

Comprobamos si el *namespace* `argocd` existe y si no, lo creamos.

Aplicamos el *manifest* para ArgoCD mediante `kubectl`.

Antes de seguir con el proceso de configuración, esperamos a que la réplica del `argocd-server` esté en estado `Ready`.

## Configuración de ArgoCD

En versiones recientes de ArgoCD es posible realizar la configuración de manera declarativa mediante *configMaps*.

En nuestro caso, configuramos el acceso sin TLS (*acceso inserguro*) mediante el *configMap*:

```yaml
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
```

También establecemos una contraseña *por defecto* para acceder a la consola, independientemente de la contraseña asignada durante la instalación (el nombre del *pod* de `argocd-server`).

Para que estos cambios tengan efecto, reiniciamos el *pod* de `argocd-server`.

## Ingress

Para poder acceder a la consola de ArgoCD, definimos un *ingress*:

```yaml
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
```

> El nombre `argocd.dev.lab` debe resolver a la IP de alguno de los nodos del clúster.
