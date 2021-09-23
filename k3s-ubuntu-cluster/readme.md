# Lab: clúster de **k3s** con Vagrant

## Generar clave SSH

```bash
ssh-keygen -t rsa -b 4096
```

## Vagrant

Las [instrucciones](https://www.vagrantup.com/downloads) para instalar Vagrant en Ubuntu/Debian:

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vagrant
```

### Clúster k3s

#### Instalación de las *Guest Additions*

Para instalar las *Guest Additions* en las máquinas virtuales provisionadas por Vagrant, primero deben estar presentes en el equipo.

Para instalarlas, ejecuta:

```bash
vagrant plugin install vagrant-vbguest
```

Si no quieres que se compruebe si las *Guest Additions* están instaladas en la máquina virtual, añade al `Vagranfile`:

```ruby
config.vm.provider "virtualbox" do |v|
  v.check_guest_additions = false
end
```

### Vagrantfile para provisionar las máquinas del clúster

El objetivo es crear un clúster de 1 nodo *server* y 2 nodos *agent*.

A nivel de [*Vagrant*](https://www.vagrantup.com/docs/providers/virtualbox/), las tres máquinas se provisionan igual; la instalación de **k3s** se realiza después usando [**k3sup**](https://github.com/alexellis/k3sup).

#### Configuración de la instalación

En el `Vagrantfile` usamos varios *scripts* para realizar acciones sobre las máquinas provisionadas, como por ejemplo generar un usuario *no-root* llamado  `operador` y habilitar el acceso vía SSH basado en usuario y contraseña.

La configuración que permite al usuario `operador` elevar privilegios sin necesidad de requerir una contraseña es un requerimiento de **k3sup**.

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
NonRootUser = 'operador'
SSHKey = '~/.ssh/id_rsa.pub'

$newUser = <<-SCRIPT
#!/bin/bash
# Create operador user
echo "Creating user #{NonRootUser} ..."
useradd -s /bin/bash -m -G sudo -U #{NonRootUser}
SCRIPT

$passwordlessSudo = <<-SCRIPT
#!/bin/bash
echo "Configuring passwordless sudoer capability for #{NonRootUser} ..."
echo "#{NonRootUser}    ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/#{NonRootUser}"
SCRIPT

$accessUsingSSHkey = <<-SCRIPT
#!/bin/bash
echo "Configuring passwordless SSH access for #{NonRootUser} ..."
sudo su #{NonRootUser}
sudo mkdir -p /home/#{NonRootUser}/.ssh/
cat /tmp/tmp_id_rsa.pub >> /home/#{NonRootUser}/.ssh/authorized_keys
SCRIPT

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.

  NodeCount = 3
  
  (1..NodeCount).each do |i|
    config.vm.define "k3s-#{i}" do |node|
      
      # Provider configuration
      node.vm.provider :virtualbox do |v|
        v.name    = "k3s-#{i}"
        v.memory  = 2048
        v.cpus    = 1
      end

      # Base configuration
      node.vm.box               = "ubuntu/focal64"
      node.vm.box_version       = "20210803.0.0"
      node.vm.box_check_update  = false
      
      node.vm.hostname          = "k3s-#{i}.192.168.1.#{100+i}.nip.io"

      # Public network configuration
      node.vm.network "public_network", ip: "192.168.1.#{100+i}", bridge: 'wlp3s0'

      # Disable sync folder
      node.vm.synced_folder ".", "/vagrant", disabled: true
      
      # Plugin vagrant-vbguest configuration
      node.vbguest.auto_update  = false

      # Create non-root user
      node.vm.provision "shell", inline: $newUser
      
      # Passwordless sudo for non-root user
      node.vm.provision "shell", inline: $passwordlessSudo
      
      # Passwordless SSH access for non-root user
      node.vm.provision "file", source: "#{SSHKey}", destination: "/tmp/tmp_id_rsa.pub"
      node.vm.provision "shell", inline: $accessUsingSSHkey
    end
  end
end
```

## Troubleshooting del aprovisionamiento con Vagrant

Usa `vagrant reload` para reiniciar la VM.

Si no funciona, puedes destruir una máquina específica con `vagrant destroy k3s-3` y recrearla de nuevo con `vagrant up`.

Si la máquina ha arrancado correctamente pero ha fallado alguno de los *scripts* de *provisioning*, se puede lanzar específicamente mediante `vagrant provision k3s-3`.

## Install k3s using k3sup

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

### Fallo de la instalación usando k3sup

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
