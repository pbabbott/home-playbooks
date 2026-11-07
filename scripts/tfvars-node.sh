#!/usr/bin/env bash
# Generates terraform/hogwarts/terraform.tfvars (gitignored) from 1Password.
#
# Usage:
#   ./scripts/tfvars-hogwarts.sh            # skip if terraform.tfvars already exists
#   ./scripts/tfvars-hogwarts.sh --force    # overwrite
#
# Requires the `op` CLI authenticated (OP_CONNECT_HOST / OP_CONNECT_TOKEN in the devcontainer) and jq.
# Item: "hogwarts-proxmox-terraform-key" in the Homelab vault.
#   username = Proxmox API token ID (e.g. terraform@pve!terraform)
#   password = Proxmox API token secret

set -euo pipefail

. "$(dirname "$0")/node-env.sh"
node_env "${NODE_ARG:-hogwarts}"
cd "$(dirname "$0")/../$TF_ROOT"

OUT=./terraform.tfvars

if [ -s "$OUT" ] && [ "${1:-}" != "--force" ]; then
    echo "$OUT already exists (use --force to overwrite)."
    exit 0
fi

echo "Fetching hogwarts Proxmox API token from 1Password..."
ITEM=$(op item get "$OP_ITEM" --vault Homelab --format=json)
TOKEN_ID=$(jq -r '.fields[] | select(.id=="username") | .value' <<<"$ITEM")
TOKEN_SECRET=$(jq -r '.fields[] | select(.id=="password") | .value' <<<"$ITEM")

for v in "$TOKEN_ID" "$TOKEN_SECRET"; do
    if [ -z "$v" ] || [ "$v" = "null" ]; then
        echo "Error: missing 'username' or 'password' field on item '$OP_ITEM'." >&2
        exit 1
    fi
done

umask 077
cat > "$OUT" <<EOF
proxmox_api_url          = "$API_URL"
proxmox_api_token_id     = "$TOKEN_ID"
proxmox_api_token_secret = "$TOKEN_SECRET"
EOF
echo "Wrote $OUT"
