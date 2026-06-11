# Incident: LVM Thin Pool Exhaustion Risk (Discard Passthrough Not Configured)

**Date:** 2026-06-10
**Status:** Partially mitigated — nonprod fstrim run, discard fix pending

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

## Next Steps

### 1. Verify nonprod cluster is healthy

Before making any VM disk config changes, confirm the nonprod cluster is
operating normally. Check in the `home-kubernetes` repository:

- All nodes `Ready` in `kubectl get nodes`
- No pending/crashing pods in `kubectl get pods -A`
- etcd healthy (`etcdctl endpoint health` or equivalent)
- Longhorn volumes healthy in the Longhorn UI or `kubectl -n longhorn-system get volumes`

### 2. Apply `discard=on` to nonprod VMs (302, 303, 304)

For each nonprod worker, update all three scsi disks to add `discard=on`:

```bash
# Example for vm-302 — repeat for 303, 304
qm set 302 --scsi0 local-lvm:vm-302-disk-0,discard=on,iothread=1,size=32G,ssd=1
qm set 302 --scsi1 fast-ssd:vm-302-disk-0,discard=on,iops_wr=500,iothread=1,mbps_wr=200,size=256G,ssd=1
qm set 302 --scsi2 etcd-ssd:vm-302-disk-0,discard=on,iothread=1,size=20G,ssd=1
```

Then re-run fstrim inside each VM and confirm thin pool percentages drop:

```bash
pvesh create /nodes/chimaera/qemu/302/agent/exec --command 'fstrim' --command '-v' --command '/'
lvs pve --noheadings -o lv_name,data_percent | grep -E '30[234]-disk'
```

### 3. If nonprod is healthy and discard fix verified — apply to prod

Repeat the same `discard=on` change for prod workers (205, 206, 207) and
controller (204). Prod workers are at 96% thin pool utilization and should be
prioritized after nonprod is confirmed stable.

Also apply to nonprod controller (301) and template VM (901) for completeness.

### 4. Enable periodic fstrim in the template

Tracked in [#19](https://github.com/pbabbott/home-playbooks/issues/19).

To prevent recurrence, ensure `fstrim.service` systemd timer runs weekly inside
all VMs. Add to the template provisioning playbook
(`playbooks/ansible-template-ubuntu-noble/`) so all future clones inherit it.

Alternatively, enable `discard` as a mount option in `/etc/fstab` inside the
template for continuous inline discard (higher IOPS overhead but no manual
fstrim needed).
