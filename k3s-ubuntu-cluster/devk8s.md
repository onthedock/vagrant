# devkube: clúster de k8s rápido y sencillo

> WIP

Inspirado por la charla de [Shell Ninja](https://www.youtube.com/watch?v=1mt2-LbKuvY) por Dr. Roland Huß en YouTube [Github: Shell Ninja](https://github.com/ro14nd-talks/shell-ninja/tree/master), voy a adaptar los diferentes comandos de despliegue creados hasta ahora para actuar de forma conjunta.

La idea es crear un comando `devkube` con varios subcomandos:

- `devkube start` crea las máquinas virtuales (usando Vagrant). Del mismo modo, `devkube stop` y `devkube destroy`. --> Equivale al actual `vagrant up`
- `devkube install` instala Kubernetes (k3s); acepta como parámetros la versión (`devkube install --release`). --> Equivale al actual `k3s_cluster_install.sh`
- `devkube deploy` para desplegar aplicaciones en el clúster. El despliegue puede ser usando Helm, usando un fichero YAML o usando ArgoCD. Ya veremos si puedo hacerlo con un sólo subcomando o con varios (por los argumentos que toma cada tipo de despliegue).
- `devkube --all` o algo por el estilo para desplegar todos (con las opciones por defecto: longhorn, argocd, etc).
