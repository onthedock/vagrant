#!/usr/bin/env bash

vagrant up
source k3s_cluster_install.sh
source deploy_longhorn_using_helm.sh
source deploy_argo_cd.sh