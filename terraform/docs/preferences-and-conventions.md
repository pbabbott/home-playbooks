# Preferences and conventions

### VM ID ranges

We use fixed ID ranges so VMs are easy to find in the Proxmox UI and in automation:

| Range | Purpose | Notes |
|-------|---------|--------|
| **900** | Templates | Managed in Terraform (`create_ubuntu_template` + `ubuntu_template_vmids`, default `noble = 901`). |
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
- **Onboard SSD (primary disk)** — Use the `storage_ssd` variable (e.g. `longhorn-ssd`) for VMs that should place their main disk on fast storage. Set `storage_ssd` in `terraform.tfvars`, then pass `storage = var.storage_ssd` for those module calls.
- **Onboard SSD (additional data disk)** — The VM module supports an optional extra SSD data disk on `scsi1`:
  - Module toggle: `enable_ssd_data_disk` (default `false`)
  - Module storage/size: `ssd_data_disk_storage`, `ssd_data_disk_size`
  - Root defaults: `enable_nonprod_worker_ssd_data_disk = true` and `nonprod_worker_ssd_data_disk_size = "256G"`
  - Current `main.tf` behavior: non-prod worker VMs (name contains `-worker-`) get this extra SSD disk automatically when the root toggle is enabled.

You can mix strategies: some VMs with only a main disk on `var.storage`, some with main disk on `var.storage_ssd`, and workers with a second SSD data disk.
