# Terraform — Proxmox VM provisioning

This directory holds one Terraform root per Proxmox host (`chimaera/`, `hogwarts/`) plus `cloudflare/`, with shared `modules/`. Run terraform from inside a root, not from here. Each root manages its host via Terraform scripts: template creation and VM lifecycle (create, update, destroy) are defined here. Configuration inside VMs is handled by Ansible; see the [root README](../README.md) for the overall architecture.

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/getting-started.md](docs/getting-started.md) | First-time setup, common commands, and workflows |
| [docs/terraform-overview.md](docs/terraform-overview.md) | Directory layout, how root and module fit together, variable flow |
| [docs/preferences-and-conventions.md](docs/preferences-and-conventions.md) | VM ID ranges, naming, and storage conventions |
| [../docs/TERRAFORM-STATE.md](../docs/TERRAFORM-STATE.md) | Where state is stored (hogwarts: NAS Postgres), how to log in, gotchas, recovery |
| [docs/proxmox-storage.md](docs/proxmox-storage.md) | How storage pools map to Terraform variables and VM placement |

Templates: **gen2 (`chimaera`, VMID 901)** is created by `playbooks/ansible-template-ubuntu-noble/` (legacy). **gen3 (`hogwarts`)**: base template 900 is defined in `hogwarts/templates.tf`, and the k3s-ready template 901 is built by `../packer/k3s-template/` (run `../scripts/build-k3s-template.sh`).

**State:** `hogwarts/` keeps its state in Postgres on the NAS; run `source ../../scripts/tfstate-env.sh` before terraform there. See [TERRAFORM-STATE.md](../docs/TERRAFORM-STATE.md).
