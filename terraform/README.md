# Terraform — Proxmox VM provisioning

This directory is the place to manage the home Proxmox server via Terraform scripts: VM lifecycle (create, update, destroy) is defined here. Configuration inside VMs is handled by Ansible; see the [root README](../README.md) for the overall architecture.

## Documentation

| Doc | Purpose |
|-----|---------|
| [docs/getting-started.md](docs/getting-started.md) | First-time setup, common commands, and workflows |
| [docs/create-ubuntu-template.md](docs/create-ubuntu-template.md) | How to run the Ubuntu cloud-init template script and what it creates in Proxmox |
| [docs/terraform-overview.md](docs/terraform-overview.md) | Directory layout, how root and module fit together, variable flow |
| [docs/preferences-and-conventions.md](docs/preferences-and-conventions.md) | VM ID ranges, naming, and storage conventions |
| [docs/template-script-parity.md](docs/template-script-parity.md) | Template script vs old notes, env vars |
