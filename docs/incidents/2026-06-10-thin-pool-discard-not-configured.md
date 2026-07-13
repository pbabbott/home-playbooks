# Incident: LVM Thin Pool Exhaustion Risk (Discard Passthrough Not Configured)

**Date:** 2026-06-10
**Status:** Resolved — 2026-07-13

## What Was Found

During a routine storage audit of Proxmox host `chimaera`, LVM thin pool
utilization for the `pve` (NVMe) pool showed prod worker VMs at ~96% allocated:

| VM | Role | Thin Pool % |
|----|------|-------------|
| vm-205 | prod worker-1 | 96.3% |
| vm-206 | prod worker-2 | 96.4% |
| vm-207 | prod worker-3 | 96.3% |
| vm-304 | nonprod worker-3 | 79.6% |
| vm-303 | nonprod worker-2 | 72.3% |
| vm-302 | nonprod worker-1 | 52.7% |

The VMs themselves were healthy — filesystem usage inside guests was 57–62%.
The discrepancy exists because deleted files inside the VMs were not returning
blocks to the LVM thin pool.

## Root Cause

All VM disks (`scsi0`, `scsi1`, `scsi2`) were provisioned without `discard=on`
in the Proxmox VM config. Without this flag, TRIM/discard commands issued by
the guest OS (via `fstrim`) are not passed through to the LVM thin pool on the
host. Blocks allocated for deleted files accumulate indefinitely.

This affects all three disk types on every VM:
- `scsi0` → `local-lvm` (root disk, NVMe `nvme0n1p3` → `pve` VG)
- `scsi1` → `fast-ssd` (Longhorn disk, SATA `sda2` → `vg_fast`)
- `scsi2` → `etcd-ssd` (etcd disk, SATA `sda1` → `vg_etcd`)

Compounding factor: `fstrim_cloned_disks=0` is set on all VMs, so Proxmox
never automatically ran fstrim after cloning from the template.

## Risk

When a thin pool runs out of allocated space, **writes fail immediately** and
VMs can crash or corrupt data. With prod workers at 96%, any significant write
burst could exhaust the pool.

## What Was Done (2026-06-10)

Ran `fstrim -v /` manually via QEMU guest agent on nonprod workers 302, 303,
304. Each reported 2–3 GiB trimmed. However, blocks did **not** return to the
pool because `discard=on` was not set — confirming the root cause.

No changes have been made to VM disk configs yet.

## Resolution (2026-07-13)

`discard=on` was confirmed already set on all worker VMs (nonprod 302–304, prod 205–206–207)
prior to the root disk resize operation on 2026-07-13.

fstrim was run on all 6 workers as part of that operation. Results:

| VM | Role | Trimmed |
|----|------|---------|
| vm-302 | nonprod worker-1 | 28.1 GiB |
| vm-303 | nonprod worker-2 | 28.2 GiB |
| vm-304 | nonprod worker-3 | 28.1 GiB |
| vm-205 | prod worker-1 | 28.2 GiB |
| vm-206 | prod worker-2 | 31.2 GiB |
| vm-207 | prod worker-3 | 30.9 GiB |

NVMe thin pool (`pve` VG) dropped from ~96% per-VM utilization to 33–37%.
Discard passthrough is working correctly on all nodes.

See `docs/runbooks/2026-07-13-worker-root-disk-resize-32g-60g.md` for full procedure.

### Remaining item

- [#19](https://github.com/pbabbott/home-playbooks/issues/19) — enable weekly `fstrim` systemd
  timer in template so future clones run periodic trim automatically.
