# Creating an Ubuntu cloud-init template for Proxmox

**Template creation is documented in a single place:** [playbooks/proxmox/README.md](../../playbooks/proxmox/README.md).

VM templates are **managed by Ansible** (playbook `playbooks/proxmox/create-ubuntu-template.yml`). Use that playbook to create or update Ubuntu cloud-init templates; Terraform then clones from the template to create VMs. See [getting-started.md](getting-started.md) and [terraform-overview.md](terraform-overview.md) for Terraform usage.
