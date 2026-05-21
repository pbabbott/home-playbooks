# playbooks/proxmox-host

One-shot playbooks targeting the Proxmox host (`chimaera`, `192.168.4.192`).
These are run directly against the host, not the template VM.

## Playbooks

### `repartition-ssd.yml`

**Destructive.** Wipes `/dev/sda` and splits it into two independent LVM thin
pools registered as Proxmox storages.

| Partition | Size | VG | Proxmox storage | Purpose |
|-----------|------|----|-----------------|---------|
| `/dev/sda1` | 256 GiB (default) | `vg_etcd` | `etcd-ssd` | Dedicated etcd data disks |
| `/dev/sda2` | remainder | `vg_fast` | `fast-ssd` | Longhorn + general workloads |

**Pre-conditions:** all VMs with disks on `longhorn-ssd` must be stopped first.

```sh
ansible-playbook -e @../../vault.yml -e confirm=yes repartition-ssd.yml
```

Key vars (override with `-e`):

| Var | Default | Notes |
|-----|---------|-------|
| `etcd_partition_size` | `256GiB` | `sgdisk` size token — adjust if more etcd VMs expected |
| `etcd_storage_name` | `etcd-ssd` | Proxmox storage ID |
| `fast_storage_name` | `fast-ssd` | Proxmox storage ID |

### `disable-ssd-power-mgmt.yml`

Installs a udev rule that sets SATA ALPM to `max_performance` on all
`scsi_host` devices, then applies it immediately. Survives reboots.

Prevents the SSD controller from idling mid-write, which causes latency spikes
that starve etcd fsyncs.

```sh
ansible-playbook -e @../../vault.yml disable-ssd-power-mgmt.yml
```

## Run order

Run `repartition-ssd.yml` first, then `disable-ssd-power-mgmt.yml`. Both are
idempotent except repartition, which refuses to run without `-e confirm=yes`.

See `docs/plans/2026-05-21-split-ssd-etcd-longhorn.md` for the full execution
sequence including template rebuild and cluster re-bootstrap.
