# Session: Split SSD — Dedicated etcd + Longhorn Storage

**Date:** 2026-05-21

## Problem

etcd was crash-looping because it shared one SSD disk (`longhorn-ssd`, backed
by `/dev/sda` as a single LVM thin pool `vg_ssd`) with Longhorn. Heavy Longhorn
write bursts on the consumer QLC SATA SSD caused controller latency spikes →
etcd fsyncs timed out → Proxmox marked the storage inactive → control plane
went down.

## What Was Built

### New playbooks

- `playbooks/proxmox-host/repartition-ssd.yml` — destructive, guarded by
  `-e confirm=yes`. Wipes `vg_ssd`, repartitions `/dev/sda` into two GPT
  partitions, creates independent VGs + LVM thin pools, registers two new
  Proxmox storages (`etcd-ssd`, `fast-ssd`).
- `playbooks/proxmox-host/disable-ssd-power-mgmt.yml` — installs a udev rule
  setting SATA ALPM to `max_performance` on all `scsi_host` devices. Persists
  across reboots.
- `playbooks/proxmox-host/README.md`

### Template playbook changes

- `create-ubuntu-template.sh` — `scsi1` now `fast-ssd:256` with write throttle
  (`mbps_wr=200,iops_wr=500`); `scsi2` new `etcd-ssd:20`, no throttle. Both
  use `iothread=1` + `virtio-scsi-single` for separate guest I/O queues.
- `03-sdb-ssd.yml` removed; replaced by `03-ssd-disks.yml` +
  `_format-and-mount-disk.yml`. Loops over both disks with size-sanity asserts
  (`sdb`→`/mnt/ssd`, `sdc`→`/mnt/etcd`).
- `configure-vm.yml` — import updated to `03-ssd-disks.yml`.
- `manual-configure-vm-steps.md` — step 3 rewritten for two disks.

### Companion changes

- `playbooks/kubernetes-gen2/files/kubeadm-config.yml.j2` — `dataDir:
  /mnt/ssd/etcd` → `dataDir: /mnt/etcd`.
- `terraform/docs/proxmox-storage.md` — updated storage name references.
- `docs/plans/2026-05-21-split-ssd-etcd-longhorn.md` — full LLM-executable
  step-by-step runbook for future re-runs.
- `INCIDENT-ETCD-STORAGE.md` — executive summary of the incident and fix.

## Final Host State (verified)

| Resource | State |
|----------|-------|
| `/dev/sda1` (256G) → `vg_etcd` → `etcd-ssd` | active |
| `/dev/sda2` (1.6T) → `vg_fast` → `fast-ssd` | active |
| `longhorn-ssd` / `vg_ssd` | gone |
| ALPM policy | `max_performance` |
| udev rule | installed |
| Prod etcd (`192.168.6.24`) `--data-dir` | `/mnt/etcd` on `/dev/sdc` |
| Nonprod etcd (`192.168.6.31`) `--data-dir` | `/mnt/etcd` on `/dev/sdc` |

## Execution Session (2026-05-21)

Carried out the full plan in `docs/plans/2026-05-21-split-ssd-etcd-longhorn.md`. Commit: `d1193f2`.

### Steps executed

1. `terraform destroy` — destroyed VMs 204–207, 301–304, LXC 208
2. Manual `qm destroy --purge` for VMs 200–203 (had `longhorn-ssd` disks) and template 902
3. `repartition-ssd.yml` — successful after 3 bug fixes (see below)
4. `disable-ssd-power-mgmt.yml` — ALPM set to `max_performance`
5. `/template-init` → `/template-configure` → `/template-finalize` — rebuilt template 901
6. `terraform apply` — recreated all VMs; HAProxy LXC networking needed manual fix (see below)
7. Bootstrapped nonprod + prod clusters via `main.yml`

### Bugs fixed during execution

| File | Bug | Fix |
|------|-----|-----|
| `repartition-ssd.yml` | Thin pool `data` LV flagged as "open" (always true when active) | Exclude attrs starting with `t` from open-LV check |
| `repartition-ssd.yml` | `parted` not installed on Proxmox host | Replaced with `sgdisk --clear -n 1:2048:+256G -n 2:0:0` |
| `repartition-ssd.yml` | `partprobe` not installed on Proxmox host | Replaced with `blockdev --rereadpt` |
| `06-kubelet.yml` | `kubeadm init` fails: ext4 `lost+found` in `/mnt/etcd` triggers preflight | Added `--ignore-preflight-errors=DirAvailable--mnt-etcd` |

### HAProxy LXC networking (LXC 208)

After recreation, `eth0` was DOWN — `systemd-networkd` fails with `status=226/NAMESPACE` in LXC containers. Fixed by installing `ifupdown` and writing `/etc/network/interfaces`. Will be correct on next reboot since the manual `ip addr add` won't pre-empt the service.

### Verification

- Both clusters: all 4 nodes `Ready`, etcd pod `Running`, `--data-dir=/mnt/etcd` confirmed
- `pvesm status`: `etcd-ssd` (~243 GiB) and `fast-ssd` (~1.53 TiB) active

## Residual Risk

Both new disks share the same physical SSD. A hardware failure still takes both
down. Mitigation: scheduled etcd snapshots to a separate target (follow-up,
not yet implemented).
