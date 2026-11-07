#!/usr/bin/env bash
# Source me: exports PKR_VAR_* for packer/k3s-template for a node.   source scripts/packer-env.sh <hogwarts|chimaera>
. "$(dirname "${BASH_SOURCE[0]:-$0}")/node-env.sh"
node_env "${1:?node}" || return 1
ITEM=$(op item get "$OP_ITEM" --vault Homelab --format=json) || return 1
export PKR_VAR_proxmox_api_url="$API_URL"
export PKR_VAR_proxmox_node="$NODE"
export PKR_VAR_base_template_id="$BASE_ID"
export PKR_VAR_template_id="$TPL_ID"
export PKR_VAR_cloud_init_storage_pool="$POOL"
export PKR_VAR_proxmox_api_token_id=$(jq -r '.fields[] | select(.id=="username") | .value' <<<"$ITEM")
export PKR_VAR_proxmox_api_token_secret=$(jq -r '.fields[] | select(.id=="password") | .value' <<<"$ITEM")
echo "PKR_VAR_* exported for $NODE"
