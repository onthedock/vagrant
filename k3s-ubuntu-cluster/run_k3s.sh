#!/usr/bin/env bash

vagrant up
source k3s-cluster-install.sh
source deploy-longhorn-using-helm.sh
source deploy_argo_cd.sh