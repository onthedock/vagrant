#!/usr/bin/env bash

declare -i E_VM_NOT_RUNNING=1
declare -i E_KUBECONFIG_NOT_FOUND=2

check_vms() {
    local node_count
    local node_names
    local vms_ok
    declare -i vms_ok=0

    node_count=$(grep -i 'NodeCount =' Vagrantfile | awk '{print $3}')
    node_names=$(grep -i '\.name' Vagrantfile | awk '{print $3}' | tr -d '"' | sed -e 's/[#{i}]//g')

    printf "\nChecking VM state after Vagrant provisioning...\n"
    for i in $(seq 1 "$node_count"); do
        local vm_status

        vm_status=$(vboxmanage showvminfo "${node_names}$i" | grep -i 'State' | awk '{print $2}')
        if [[ "$vm_status" = "running" ]]; then
            vms_ok=$((vms_ok +1))
        fi
        printf "\t%s%i: %s\n" "${node_names}" "$i" "$vm_status"
    done

    if [[ "vms_ok" -eq "$node_count" ]]; then
        printf "\t---------------------\n"
        printf "\tAll VMs running (%s/%i)\n" "$node_count" "$vms_ok"
    else
        printf "\t---------------------\n"
        printf "\tOne or more VMs are not running\n"
        printf "\tExpected %s, but got %i\n" "$node_count" "$vms_ok"
        exit $E_VM_NOT_RUNNING
    fi
}

check_k3s() {
    if [[ -f "$PWD/kubeconfig" ]]; then
        printf "\n %s created...\n" "$PWD/kubeconfig"
        printf "\tExporting it as KUBECONFIG\n"
        export KUBECONFIG="$PWD/kubeconfig"
    else
        printf "\nkubeconfig file not present\n"
        printf "\tUnable to continue.\n"
        exit $E_KUBECONFIG_NOT_FOUND
    fi
    
    k3s_info=$(kubectl cluster-info | grep -i 'kubernetes')
    if [[ ! -z "$k3s_info" ]] ;then
        printf "\n\t%s\n" "$k3s_info"
        printf "\n%s\n" "$(kubectl get nodes)"
    else
        printf "kubeconfig file not created "
        printf "Kubernetes API server not reachable"
    fi
}

vagrant up
check_vms

source k3s_cluster_install.sh
check_k3s
source deploy_longhorn_using_helm.sh
source deploy_argo_cd.sh