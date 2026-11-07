#!/usr/bin/env bash
# Source me: exports PKR_VAR_* for packer/k3s-template from 1Password (same item as tfvars-hogwarts.sh).
#   source scripts/packer-env-hogwarts.sh
ITEM=$(op item get "hogwarts-proxmox-terraform-key" --vault Homelab --format=json) || return 1
export PKR_VAR_proxmox_api_url="https://192.168.4.196:8006/api2/json"
export PKR_VAR_proxmox_api_token_id=$(jq -r '.fields[] | select(.id=="username") | .value' <<<"$ITEM")
export PKR_VAR_proxmox_api_token_secret=$(jq -r '.fields[] | select(.id=="password") | .value' <<<"$ITEM")
echo "PKR_VAR_* exported for hogwarts"
