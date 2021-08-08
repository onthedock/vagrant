#!/usr/bin/env bash

VERSIONS_FILE=versions.txt
echo "" > $VERSIONS_FILE

log_version(){
  echo "$1 version:" | tee -a $VERSIONS_FILE
  echo "------------------------------------------" | tee -a $VERSIONS_FILE
}

log_version "Vagrant"
vagrant version >> $VERSIONS_FILE
echo "" | tee -a $VERSIONS_FILE

log_version "k3sup"
k3sup version >> $VERSIONS_FILE
echo "" | tee -a $VERSIONS_FILE

log_version "kubectl"
if [ -z KUBECONFIG ]
then
  kubectl version --short >> versions.txt
else
  kubectl version --short --client >> versions.txt
fi
