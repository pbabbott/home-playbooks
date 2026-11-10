#!/usr/bin/env bash
# Source me: node_env <hogwarts|chimaera> sets the per-Proxmox-host settings used by the k3s template scripts.
# Chimaera's 900/901 are the legacy gen2 templates: never use them there (k3s template is 910/911).
node_env() {
  NODE=${1:?usage: node_env <hogwarts|chimaera>}
  case "$NODE" in
    hogwarts)
      PVE_IP=192.168.4.196; BASE_ID=900; TPL_ID=901; POOL=local-lvm; TF_ROOT=terraform/hogwarts
      OP_ITEM=hogwarts-proxmox-terraform-key; TEMP_RAM=4096 ;;
    chimaera)
      PVE_IP=192.168.4.192; BASE_ID=910; TPL_ID=911; POOL=local-lvm; TF_ROOT=terraform/chimaera
      OP_ITEM=${CHIMAERA_OP_ITEM:-chimaera-proxmox-terraform-key}
      TEMP_RAM=2048 ;;
    *) echo "unknown node '$NODE' (hogwarts|chimaera)" >&2; return 1 ;;
  esac
  PVE=root@$PVE_IP
  API_URL="https://$PVE_IP:8006/api2/json"
  BASE_RESOURCE='module.base_template.proxmox_virtual_environment_vm.base'
  export NODE PVE PVE_IP BASE_ID TPL_ID POOL TF_ROOT OP_ITEM API_URL TEMP_RAM BASE_RESOURCE
}
