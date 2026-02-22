# Preferences and conventions

### VM ID ranges

We use fixed ID ranges so VMs are easy to find in the Proxmox UI and in automation:

| Range | Purpose | Notes |
|-------|---------|--------|
| **900** | Templates | Created by hand or `scripts/create-ubuntu-template.sh`. Not managed by Terraform. |
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

- **Default disk** — Use the `storage` variable (e.g. `local-lvm`) for most VMs. Pass it as the module's `storage` argument.
- **Onboard SSD** — Use the `storage_ssd` variable (e.g. `longhorn-ssd`) for VMs that should sit on fast disk. Set `storage_ssd` in `terraform.tfvars`, then pass `storage = var.storage_ssd` to the module for those VMs.

You can mix: some VMs on `var.storage`, others on `var.storage_ssd`, depending on the module arguments in `main.tf`.
