#!/usr/bin/env bash

IPControlPlaneNode=192.168.1.101
REMOTE_USER=operador
K3S_VERSION="v1.26.0+k3s1"

# Install the ControlPlane
k3sup install --ip $IPControlPlaneNode \
    --user $REMOTE_USER \
    --k3s-extra-args='--flannel-iface enp0s8' \
    --k3s-version $K3S_VERSION
              
# Install the K8s agent nodes
node_count=$(grep -i 'NodeCount =' Vagrantfile | awk '{print $3}')
ip_oct_1=$(echo $IPControlPlaneNode | awk -F\. '{print $1}')
ip_oct_2=$(echo $IPControlPlaneNode | awk -F\. '{print $2}')
ip_oct_3=$(echo $IPControlPlaneNode | awk -F\. '{print $3}')
ip_oct_4=$(echo $IPControlPlaneNode | awk -F\. '{print $4}')

for ((i=1; i<node_count; i++));do
    IP_K8S_AGENT="$ip_oct_1.$ip_oct_2.$ip_oct_3.$((ip_oct_4+i))"
    k3sup join --ip  "$IP_K8S_AGENT" \
        --server-ip $IPControlPlaneNode\
        --user $REMOTE_USER\
        --k3s-extra-args='--flannel-iface enp0s8' \
        --k3s-version $K3S_VERSION
done

# k3sup join --ip $IPWorkerNode1 \
#            --server-ip $IPControlPlaneNode\
#            --user $REMOTE_USER\
#            --k3s-extra-args='--flannel-iface enp0s8' \
#            --k3s-version $K3S_VERSION

# k3sup join --ip $IPWorkerNode2 \
#            --server-ip $IPControlPlaneNode \
#            --user $REMOTE_USER \
#            --k3s-extra-args='--flannel-iface enp0s8' \
#            --k3s-version $K3S_VERSION
