# Terraform — Proxmox VM provisioning

This directory is the place to manage the home Proxmox server via Terraform scripts: template creation and VM lifecycle (create, update, destroy) are defined here. Configuration inside VMs is handled by Ansible; see the [root README](../README.md) for the overall architecture.

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/getting-started.md](docs/getting-started.md) | First-time setup, common commands, and workflows |
| [docs/terraform-overview.md](docs/terraform-overview.md) | Directory layout, how root and module fit together, variable flow |
| [docs/preferences-and-conventions.md](docs/preferences-and-conventions.md) | VM ID ranges, naming, and storage conventions |
| [docs/proxmox-storage.md](docs/proxmox-storage.md) | How storage pools map to Terraform variables and VM placement |

The Ubuntu cloud-init template is created by **playbooks/proxmox/create-ubuntu-template.yml** (run that playbook before Terraform apply).
