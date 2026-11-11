# chimaera-shutdown

Clean power-off of `chimaera` (192.168.4.192) before physically moving it, and the checks after it comes back.

**Impact:** only gen3 controller-3 (VM 215) and worker-3 (VM 216) go away. The rest of gen3 and the public ingress (HAProxy `.29` on hogwarts) stay up. etcd drops to 2 of 3 members (quorum holds). Longhorn volumes with a replica on worker-3 run degraded until it returns and rebuilds. Pods on worker-3 (ARC runners etc.) are rescheduled to workers 1/2. Chimaera hosts no LXCs.

```sh
# shutdown (needs -e confirm_shutdown=true)
ansible-playbook -i inventories/physical -i inventories/gen3 -e @./vault.yml playbooks/chimaera-shutdown/shutdown.yml -e confirm_shutdown=true
# after moving + power on
ansible-playbook -i inventories/physical -i inventories/gen3 -e @./vault.yml playbooks/chimaera-shutdown/startup.yml
```

| File | What |
|---|---|
| `shutdown.yml` | On controller-1: check the other controllers are Ready, **fail if any Longhorn volume is not healthy** (override: `-e allow_degraded=true`), etcd snapshot, cordon + drain worker-3 and controller-3 (Longhorn instance-managers excluded, `--disable-eviction`, same reasoning as `hogwarts-shutdown/`), **gate: no volume attached to worker-3 and all attached volumes healthy**. On chimaera: `qm shutdown` 216, 215 (force-stop after timeout), verify nothing runs, `sync`, `poweroff`. |
| `startup.yml` | Waits for chimaera and both VMs (`onboot: 1`), both nodes Ready, **uncordons worker-3 only** (controller-3 stays cordoned by design), waits up to 30 min for Longhorn rebuilds, reports degraded volumes, non-running pods and etcd members. |

## Before
- Tell anyone who uses ARC runners / CI: worker-3 is gone for the duration.
- Worker-3 pods land on workers 1/2 (hogwarts); check they have room if you drain a lot.
- Keep the NAS and `bananapi` up (needed at boot).

## After moving
- Same MAC + eero DHCP reservation keeps `192.168.4.192`. VMs use static `192.168.6.45`/`.46`; check the switch port and cable.
- Set BIOS "restore on AC power" = on for an unattended boot, otherwise press the power button.
- The 2 TB SATA SSD power-management rule (`proxmox-chimaera/disable-ssd-power-mgmt.yml`) is persistent; nothing to re-run.
- If the SSD/NVMe does not show up after the move, reseat and check `lsblk` before starting VMs; storage: `local-lvm` (SATA), `nvme-fast` (NVMe).

## Required variables
| Variable | From |
|---|---|
| `inventoryPasswords.chimaera` | vault (`-e @./vault.yml`) |
| `confirm_shutdown` | `-e` on the command line (shutdown only) |
| controller-1 access | key auth as `firebolt` (`inventories/gen3`) |

## Status
Verified end to end 2026-11-11. `shutdown.yml`: no hangs, cluster stayed healthy on the other 4 nodes. `startup.yml`: both VMs came up, nodes Ready, worker-3 uncordoned (controller-3 left cordoned), Longhorn rebuilt in about 1.5 min, all pods Running/Completed, 3 etcd members.
