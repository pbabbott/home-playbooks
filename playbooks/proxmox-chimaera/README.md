# playbooks/proxmox-chimaera

> **Obsolete since 2026-11-10:** chimaera was reinstalled (PVE 9.2.2). The OS and `local-lvm` are on the SATA SSD and `nvme-fast` is on the NVMe, so `repartition-ssd.yml` and the `etcd-ssd`/`fast-ssd` layout below no longer apply (do not run it). Only `disable-ssd-power-mgmt.yml` is still relevant. Current layout: `docs/HOSTS.md`, previous config: in git history (deleted `docs/CHIMAERA-PRE-REINSTALL.md`).

One-shot SSD playbooks for the Proxmox host `chimaera` (`192.168.4.192`), which runs the prod gen2 cluster. Renamed from `proxmox-host` because there is now a second Proxmox host, `hogwarts`; **these plays are not meant for `hogwarts`.**

**Status: applied, legacy, kept to document `chimaera`'s disk layout.** Written in May 2026 while fixing disk problems with the whole cluster on a single SSD. It may have helped separate etcd and Longhorn onto their own partitions, but most things still end up on one drive, and the effort did not work out well. `chimaera` is essentially maxed out. The disk layout is not documented anywhere else, which is why this code stays for now.

**Exception to the `main.yml` convention:** no `main.yml`. These are one-shot, one of them is destructive, and the directory is expected to be deleted or folded into docs (see TODOs).

## Playbooks

Both target `chimaera` only. Run from the repo root.

| File | What it does |
|---|---|
| `repartition-ssd.yml` | **Destructive.** Wipes `/dev/sda` and splits it into two LVM thin pools registered as Proxmox storages. Refuses to run without `-e confirm=yes`. All VMs using `longhorn-ssd` must be stopped first. |
| `disable-ssd-power-mgmt.yml` | Installs a udev rule (`/etc/udev/rules.d/60-ssd-power-mgmt.rules`) setting SATA ALPM to `max_performance` on all `scsi_host` devices and applies it now. Meant to stop the SSD idling mid-write, which caused latency spikes and etcd fsync timeouts. |

```sh
# Do not re-run: already applied
ansible-playbook -e @./vault.yml -e confirm=yes playbooks/proxmox-chimaera/repartition-ssd.yml
ansible-playbook -e @./vault.yml playbooks/proxmox-chimaera/disable-ssd-power-mgmt.yml
```

Run order when it was applied: repartition first, then power management. See `docs/plans/2026-05-21-split-ssd-etcd-longhorn.md` for the full sequence including template rebuild and cluster re-bootstrap (it still uses the old `proxmox-host` path).

## Resulting disk layout (what `repartition-ssd.yml` builds)

| Partition | Size | VG | Proxmox storage | Purpose |
|---|---|---|---|---|
| `/dev/sda1` | 256G (`etcd_partition_size`) | `vg_etcd` | `etcd-ssd` | Dedicated etcd data disks |
| `/dev/sda2` | remainder | `vg_fast` | `fast-ssd` | Longhorn and general workloads |

Each VG has a thin pool `data` (95% of the VG). It replaced the old `longhorn-ssd` storage (VG `vg_ssd`). Other disks (e.g. `local-lvm` root) are not covered here.

Variables are inline in the plays and overridable with `-e` (`etcd_partition_size`, `etcd_storage_name`, `fast_storage_name`, and others). Secrets come from the vault.

## TODO / open questions

- **Decide whether any of this is worth keeping**, then delete the playbooks. Before deleting, check whether anything should be captured first (the layout above, the ALPM udev rule).
- Document the actual current disk layout of `chimaera` (verify with `lsblk`, `vgs`, `pvesm status`); it is not documented anywhere else. Do the same for `hogwarts`.
- Verify whether the ALPM change actually fixed the latency spikes (unknown).
- Any other hand-made host tweaks on `chimaera` are unknown.
- `docs/plans/` and `docs/claude-sessions/` still reference the old `playbooks/proxmox-host/` path (left as historical).
