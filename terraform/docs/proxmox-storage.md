# Proxmox storage guide for this Terraform stack

This document maps Proxmox storage pools to the Terraform variables in this directory.

For broader context, see:

- [terraform-overview.md](terraform-overview.md)
- [preferences-and-conventions.md](preferences-and-conventions.md)

---

## Storage controls in Terraform

| Variable | Defined in | What it controls |
|---|---|---|
| `storage` | root `variables.tf` | Default VM disk storage for module-managed VMs (`main.tf` currently passes `var.storage`). |
| `storage_ssd` | root `variables.tf` | Optional fast storage target; used when a module call passes it as `storage`. |
| `enable_nonprod_worker_ssd_data_disk` | root `variables.tf` | Toggle that enables an additional SSD data disk for non-prod worker VMs. |
| `nonprod_worker_ssd_data_disk_size` | root `variables.tf` | Size of that worker SSD data disk (default `256G`). |
| `cloudinit_cdrom_storage` | `modules/vm/variables.tf` | Optional per-VM override for cloud-init CDROM storage; if unset, module falls back to VM disk `storage`. |
| `enable_ssd_data_disk` / `ssd_data_disk_storage` / `ssd_data_disk_size` | `modules/vm/variables.tf` | Module-level controls for an optional second disk attached at `scsi1`. |

---

## Common Proxmox storage pools

### `local`

Directory-based storage (`/var/lib/vz` by default). Typically used for:

- ISO images
- CT templates
- Backups

Usually **not** where you place actively running VM disks.

### `local-lvm`

LVM-thin storage usually used for:

- VM disks
- CT volumes
- Cloud-init drives

Good default for general-purpose VM workloads.

### `longhorn-ssd` (custom)

Example of a custom, SSD-backed storage target used for higher-performance or larger-disk workloads.
In this repo it is represented by `storage_ssd`.

The name suggests use with [Longhorn](https://longhorn.io/) workloads, but the Terraform code treats it as a normal Proxmox storage value.

---

## How current code places disks

1. **Template** — Created by `playbooks/proxmox/create-ubuntu-template.yml`; storage is configured in that playbook, not in Terraform.

2. **Non-prod VM module calls (`main.tf`)** — Current active module uses `storage = var.storage`. Worker nodes (name contains `-worker-`) get an additional SSD data disk when `enable_nonprod_worker_ssd_data_disk = true`. Worker data disk storage uses `storage_ssd` when set, otherwise falls back to `storage`.

3. **VM module internals (`modules/vm/main.tf`)**
   - Main disk uses `var.storage`.
   - Optional worker data disk uses `scsi1` with `ssd_data_disk_storage` and `ssd_data_disk_size`.
   - Cloud-init CDROM uses `coalesce(var.cloudinit_cdrom_storage, var.storage)`.

---

## Practical selection guidance

- Use `storage` for the baseline pool most VMs should use.
- Keep `storage_ssd` as an opt-in target for workloads that need faster or larger storage.

Example `terraform.tfvars` pattern:

```hcl
storage     = "local-lvm"
storage_ssd = "longhorn-ssd"
```

---

## Validation checklist

When storage-related applies fail, verify:

1. The storage name matches exactly what Proxmox reports.
2. The storage allows the required content type (`images` for VM disks).
3. The target node can access that storage.
4. VM settings (`storage`/`storage_ssd`) are aligned with intended placement.