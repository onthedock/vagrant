# Install k3s using k3sup

Instalamos **k3sup**:

```bash
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/
```

Para validar la instalación, ejecutamos:

```bash
$ k3sup version
 _    _____                 
| | _|___ / ___ _   _ _ __
| |/ / |_ \/ __| | | | '_ \
|   < ___) \__ \ |_| | |_) |
|_|\_\____/|___/\__,_| .__/ 
                     |_|    
Version: 0.11.0                                                                                                                
Git Commit: fd9dfeaa6cd32f0d048f33705a04c14ca4aa3550

Give your support to k3sup via GitHub Sponsors:

https://github.com/sponsors/alexellis
```

Como tenemos las máquinas provisionadas con Vagrant y con IPs estáticas, instalamos el clúster de **k3s** mediante:

```bash
#!/usr/bin/env bash

export IPControlPlaneNode=192.168.1.101
export IPWorkerNode1=192.168.1.102
export IPWorkerNode2=192.168.1.103
export REMOTE_USER=operador
# Vagrant uses the first network interface and set it as NAT
# That's why we have to explicitly bind flannel to use the bridged
# interface.
export EXTRA_ARGS='--flannel-iface enp0s8'

# Install the ControlPlane
k3sup install --ip $IPControlPlaneNode --user $REMOTE_USER --k3s-extra-args=$EXTRA_ARGS
# Install the agents/worker nodes
k3sup join --ip $IPWorkerNode1 --server-ip $IPControlPlaneNode --user $REMOTE_USER --k3s-extra-args=$EXTRA_ARGS
k3sup join --ip $IPWorkerNode2 --server-ip $IPControlPlaneNode --user $REMOTE_USER --k3s-extra-args=$EXTRA_ARGS
```

Lanzamos la instalación del clúster:

```bash
./k3s-cluster-install.sh 
```

La instalación genera el fichero `kubeconfig` en la carpeta local.

Instala `kubectl`:

```bash
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/
# Validation:
kubectl version --short
```

Y ahora ya podemos conectar con nuestro clúster:

```bash
export KUBECONFIG=`pwd`/kubeconfig
kubectl get nodes
```

## Fallo de la instalación usando k3sup

Los agentes no pueden contactar con el nodo `server` porque se está usando la tarjeta de red *por defecto* de Virtual Box, que está configurda como NAT (con IP 10.0.2.15):

```bash
$ sudo journalctl -u k3s-agent
...
level=info msg="Updating load balancer server addresses -> [10.0.2.15:6443 192.168.1.101:6443]"
Aug 08 09:52:18 k3s-2 k3s[17365]: time="2021-08-08T09:52:18.738146716Z" level=info msg="Connecting to proxy" url="wss://10.0.2.15:6443/v1-k3s/connect"
Aug 08 09:52:18 k3s-2 k3s[17365]: time="2021-08-08T09:52:18.738524280Z" level=error msg="Failed to connect to proxy" error="dial tcp 10.0.2.15:6443: connect: connection refused"
Aug 08 09:52:18 k3s-2 k3s[17365]: time="2021-08-08T09:52:18.738679770Z" level=error msg="Remotedialer proxy error" error="dial tcp 10.0.2.15:6443: connect: connection refused"
...

```

La solución pasa por explicitar la tarjeta de red que debe usar Flannel mediante `--flannel-iface <device>`
