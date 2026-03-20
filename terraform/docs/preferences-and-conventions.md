# Preferences and conventions

### VM ID ranges

We use fixed ID ranges so VMs are easy to find in the Proxmox UI and in automation:

| Range | Purpose | Notes |
|-------|---------|--------|
| **900** | Templates | Created by `playbooks/proxmox/create-ubuntu-template.yml` (e.g. noble = 901). Terraform expects the template to exist before applying. |
| **200** | Production infra | e.g. k8s nodes, core services. |
| **300** | Non-prod | Test, staging, experiments. |
| **500** | Dev workstations | Personal or shared dev VMs. |

When adding a VM in Terraform, set the `vmid` argument on the `vm` module to an unused ID in the right range (e.g. `301`, `302` for non-prod).

### VM naming

Use names that include **who manages them** and **which environment** so you don't confuse them with production or hand-created VMs:

- **Prefix** — `tf-` = Terraform-managed.
- **Environment** — e.g. `nonprod`, or later `prod` if you manage production with Terraform.
- **Role/host** — e.g. `k8s-controller-1`, `k8s-worker-1`.

Examples: `tf-nonprod-k8s-controller-1`, `tf-nonprod-k8s-worker-1`. Production (200 range) might stay as `k8s-controller-1`, `k8s-worker-1`; non-prod (300 range) uses `tf-nonprod-*` so the Proxmox UI and Ansible inventory stay unambiguous.

### Storage

- **VM disks** — Defined on the **template** (Ansible / Proxmox), not in Terraform. Clones inherit that layout.
- **Terraform `storage`** — Proxmox pool for the **cloud-init** drive on cloned VMs (e.g. `local-lvm`). Pass it as the module `storage` argument from root `var.storage`.
- **Per-VM override** — Optional module input `cloudinit_cdrom_storage` if a clone should store cloud-init on a different pool than `storage`.
