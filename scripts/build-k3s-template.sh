#!/usr/bin/env bash
# Rebuilds the k3s template on a Proxmox node end to end: ensure verified base image + base template, replace the k3s
# template via Packer, then smoke-test it. Usage: ./scripts/build-k3s-template.sh [hogwarts|chimaera]  (default hogwarts)
# IDs per node: scripts/node-env.sh. Needs `op` access for the Proxmox token.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ./scripts/node-env.sh
node_env "${1:-hogwarts}"

# Safety: never touch the legacy gen2 templates on chimaera.
if [ "$NODE" = chimaera ] && { [ "$TPL_ID" = 900 ] || [ "$TPL_ID" = 901 ] || [ "$BASE_ID" = 900 ] || [ "$BASE_ID" = 901 ]; }; then
  echo "refusing: 900/901 on chimaera are the gen2 templates" >&2; exit 1
fi

NODE_ARG=$NODE ./scripts/tfvars-node.sh
# shellcheck disable=SC1091
source ./scripts/tfstate-env.sh
terraform -chdir="$TF_ROOT" init -input=false >/dev/null
terraform -chdir="$TF_ROOT" apply -input=false -auto-approve -target="$BASE_RESOURCE"

# shellcheck disable=SC1091
source ./scripts/packer-env.sh "$NODE"
if ssh "$PVE" "qm status $TPL_ID" >/dev/null 2>&1; then
  echo "Replacing existing template $TPL_ID on $NODE: $(ssh "$PVE" "qm config $TPL_ID | grep ^name:")"
  ssh "$PVE" "qm config $TPL_ID | grep -q '^name: tpl-k3s-noble' && qm destroy $TPL_ID --purge 1" \
    || { echo "VM $TPL_ID is not tpl-k3s-noble; refusing to destroy" >&2; exit 1; }
fi
(cd packer/k3s-template && packer init . && packer build .)
./scripts/verify-k3s-template.sh "$NODE" "$TPL_ID"
