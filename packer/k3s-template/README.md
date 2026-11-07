# packer/k3s-template

Builds template `901` (`tpl-k3s-noble`) on `hogwarts` by cloning base template `900` and running
[`playbooks/k3s-template/main.yml`](../../playbooks/k3s-template/main.yml). Rebuilding replaces 901 (delete it first: `ssh root@192.168.4.196 qm destroy 901`).

## Prerequisites
1. Base template 900: `cd terraform/hogwarts && terraform apply` (see `templates.tf`).
2. Packer installed (devcontainer; rebuild it if `packer` is missing).
3. Token env vars: `source ../../scripts/packer-env-hogwarts.sh` (1Password).
4. `build_ip` (default 192.168.6.250) must be free.

## Build
```sh
cd packer/k3s-template
source ../../scripts/packer-env-hogwarts.sh
packer init .
packer validate .
packer build .
```

## Required variables
`proxmox_api_url`, `proxmox_api_token_id`, `proxmox_api_token_secret` (from `PKR_VAR_*`, set by the script). Others have defaults in `variables.pkr.hcl`.
