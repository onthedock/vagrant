#!/usr/bin/env bash

IPControlPlaneNode=192.168.1.101
IPWorkerNode1=192.168.1.102
IPWorkerNode2=192.168.1.103
REMOTE_USER=operador
K3S_VERSION="v1.22.3+k3s1"

# Install the ControlPlane
k3sup install --ip $IPControlPlaneNode \
              --user $REMOTE_USER \
              --k3s-extra-args='--flannel-iface enp0s8' \
              --k3s-version $K3S_VERSION
              
# Install the agents/worker nodes
k3sup join --ip $IPWorkerNode1 \
           --server-ip $IPControlPlaneNode\
           --user $REMOTE_USER\
           --k3s-extra-args='--flannel-iface enp0s8' \
           --k3s-version $K3S_VERSION

k3sup join --ip $IPWorkerNode2 \
           --server-ip $IPControlPlaneNode \
           --user $REMOTE_USER \
           --k3s-extra-args='--flannel-iface enp0s8' \
           --k3s-version $K3S_VERSION