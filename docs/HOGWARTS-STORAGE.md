# hogwarts disk layout

`hogwarts` (192.168.4.196, Proxmox VE 9.2, standalone node) has three NVMe drives. Configured 2026-11-07, by hand over SSH (no playbook yet).
Host role: [`HOSTS.md`](HOSTS.md). `playbooks/proxmox-chimaera/` must NOT be run on this host.

## Drives

Always identify by serial, never by `/dev/nvmeXn1` (names can swap across reboots). Use `/dev/disk/by-id/nvme-<model>_<serial>`.

| Drive | Model | Serial | Size | Role | Device at setup |
|---|---|---|---|---|---|
| 1 | WD PC SN8000S 1TB | 25354M801046 | 953.9G | OS: ESP, `pve` VG (root 96G, swap 8G, `data` thin pool) | `nvme0n1` |
| 2 | Samsung 990 PRO 2TB | S7L9NJ0L808334P | 1.8T | Generic VM pool `vm-nvme-01` | `nvme1n1` |
| 3 | Samsung 990 PRO 2TB | S7L9NJ0L808167P | 1.8T | Generic VM pool `vm-nvme-02` | `nvme2n1` |

## Proxmox storages

| Storage ID | Type | Backing | Capacity | Content |
|---|---|---|---|---|
| `local` | dir | `/var/lib/vz` on `pve/root` | ~94 GiB | iso, vztmpl, backup, import |
| `local-lvm` | lvmthin | `pve/data` | ~815 GiB | images, rootdir |
| `vm-nvme-01` | lvmthin | `vg_nvme01/thinpool_nvme01` | 1.82 TiB | images, rootdir |
| `vm-nvme-02` | lvmthin | `vg_nvme02/thinpool_nvme02` | 1.82 TiB | images, rootdir |

Terraform references the storage IDs (`vm-nvme-01`, `vm-nvme-02`) as datastores.

## Design rules

- The 2TB drives are fully independent: no RAID, no shared VG, nothing spans drives. Losing one drive loses only the VMs on it.
- Pools are generic; no permanent CI or prod role is assigned.
- Each 2TB drive: one GPT partition (type 8e00, named after the VG) -> one PV -> one VG -> one thin pool using 100% of the VG (LVM auto-created 120 MiB metadata + 120 MiB spare).
- Thin pools use LVM defaults: 1 MiB chunk size, zeroing on (LVM warns this slows provisioning; same as the Proxmox GUI default).
- **Thin snapshots are not backups.** VM backups go to the NAS (`room_of_requirement`).

## Recreate (destructive: wipes the drive)

Per drive, with `D=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_<serial>` and `NN` = `01` or `02`. Verify serial and `wipefs -n $D` first; `partprobe` is not installed.

```sh
sgdisk -n1:0:0 -t1:8e00 -c1:vg_nvmeNN $D
blockdev --rereadpt $(readlink -f $D); udevadm settle
pvcreate ${D}-part1
vgcreate vg_nvmeNN ${D}-part1
lvcreate --type thin-pool -l 100%FREE -n thinpool_nvmeNN vg_nvmeNN
pvesm add lvmthin vm-nvme-NN --vgname vg_nvmeNN --thinpool thinpool_nvmeNN --content images,rootdir
```

If the storage already exists, `pvesm remove vm-nvme-NN` and `vgremove` first, with all VMs on it gone.

## Verify

```sh
lsblk -o NAME,MODEL,SERIAL,SIZE,FSTYPE
pvs; vgs; lvs -a
pvesm status
pvesm alloc vm-nvme-01 9999 vm-9999-disk-0 1G && pvesm free vm-nvme-01:vm-9999-disk-0   # smoke test
```

Health at setup: both 990 PROs SMART PASSED, 0% used.
