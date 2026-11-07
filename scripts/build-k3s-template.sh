#!/usr/bin/env bash
# Rebuilds template 901 on hogwarts end to end: ensure verified base image, ensure base template 900,
# replace 901 via Packer, then smoke-test it. Run from anywhere; needs `op` access for the Proxmox token.
set -euo pipefail
cd "$(dirname "$0")/.."
PVE=root@192.168.4.196

./scripts/tfvars-hogwarts.sh
# shellcheck disable=SC1091
source ./scripts/tfstate-env.sh
terraform -chdir=terraform/hogwarts init -input=false >/dev/null
terraform -chdir=terraform/hogwarts apply -input=false -auto-approve -target=proxmox_virtual_environment_vm.tpl_ubuntu_noble_base

# shellcheck disable=SC1091
source ./scripts/packer-env-hogwarts.sh
if ssh "$PVE" 'qm status 901' >/dev/null 2>&1; then
  echo "Replacing existing template 901..."
  ssh "$PVE" 'qm destroy 901 --purge 1'
fi
(cd packer/k3s-template && packer init . && packer build .)
./scripts/verify-k3s-template.sh 901
