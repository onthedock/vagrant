#!/usr/bin/env bash

export IPControlPlaneNode=192.168.1.101
export IPWorkerNode1=192.168.1.102
export IPWorkerNode2=192.168.1.103
export REMOTE_USER=operador

# Install the ControlPlane
k3sup install --ip $IPControlPlaneNode --user $REMOTE_USER --k3s-extra-args='--flannel-iface enp0s8'
# Install the agents/worker nodes
k3sup join --ip $IPWorkerNode1 --server-ip $IPControlPlaneNode --user $REMOTE_USER --k3s-extra-args='--flannel-iface enp0s8'
k3sup join --ip $IPWorkerNode2 --server-ip $IPControlPlaneNode --user $REMOTE_USER --k3s-extra-args='--flannel-iface enp0s8'
