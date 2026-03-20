# Proxmox storage guide for this Terraform stack

This document maps Proxmox storage pools to the Terraform variables in this directory.

For broader context, see:

- [terraform-overview.md](terraform-overview.md)
- [preferences-and-conventions.md](preferences-and-conventions.md)

---

## Storage controls in Terraform

| Variable | Defined in | What it controls |
|---|---|---|
| `storage` | root `variables.tf` | Proxmox pool where **cloud-init snippets** for cloned VMs are stored (e.g. `local-lvm`). VM data disks are **not** managed by Terraform; they come from the template. |
| `cloudinit_cdrom_storage` | `modules/vm/variables.tf` | Optional per-VM override for cloud-init CDROM storage; if unset, the module uses `storage`. |

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

Good default for cloud-init snippet storage (`storage` in Terraform) and for disks defined on the **template** in Ansible.

### Custom SSD pools (e.g. `longhorn-ssd`)

If the template or playbooks place disks on a fast pool, that is configured **outside** this Terraform stack (template playbook / Proxmox). Terraform only needs a pool that accepts cloud-init/snippet content for clones.

---

## How disks relate to this repo

1. **Template** — Created by `playbooks/proxmox/create-ubuntu-template.yml` (or equivalent). All boot and data disks for clones are defined there (or on the template VM in Proxmox), not in `modules/vm/main.tf`.

2. **Cloned VMs (`modules/vm/main.tf`)** — Full clone from the template. No `disk` blocks in Terraform; `lifecycle.ignore_changes` includes `disk` so Terraform does not try to strip or resize cloned disks.

3. **Cloud-init** — `initialization.datastore_id` uses `storage` (or `cloudinit_cdrom_storage`) so Proxmox knows where to put the cloud-init drive for the clone.

---

## Practical selection guidance

- Set `storage` in `terraform.tfvars` to a pool that allows **snippet** / cloud-init content (often the same pool you use for VM images, e.g. `local-lvm`).

Example:

```hcl
storage = "local-lvm"
```

---

## Validation checklist

When storage-related applies fail, verify:

1. The storage name matches exactly what Proxmox reports.
2. The storage allows the required content types for cloud-init (and that your template’s disks use pools the node can access).
3. The target node can access that storage.
