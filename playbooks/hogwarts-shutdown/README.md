# hogwarts-shutdown

Clean power-off of `hogwarts` before physically moving it, and the checks after it comes back.

**Impact:** all gen3 k3s nodes except the detached chimaera ones (controllers 210/214, workers 211/212) and the gen3 HAProxy LXC 213 (`192.168.6.29`, public ingress) run here. The whole cluster and public sites are down for the move. `marauders-map` (500) is already stopped. Also stops NTP for the LAN (`time-server/`).

```sh
# shutdown (needs -e confirm_shutdown=true)
ansible-playbook -i inventories/physical -i inventories/gen3 -e @./vault.yml playbooks/hogwarts-shutdown/shutdown.yml -e confirm_shutdown=true
# after moving + power on
ansible-playbook -i inventories/physical -i inventories/gen3 -e @./vault.yml playbooks/hogwarts-shutdown/startup.yml
```

| File | What |
|---|---|
| `shutdown.yml` | On controller-1: etcd snapshot, cordon all nodes, drain all nodes **except Longhorn instance-managers** (their PDBs never allow eviction), then **gate: wait until every Longhorn volume is `detached`** (fails before any VM is touched otherwise). On hogwarts: `qm shutdown` workers 212, 211, then controllers 214, 210, then LXC 213 (ACPI, force-stop after timeout), verify nothing runs, `sync`, `poweroff`. |
| `startup.yml` | Waits for hogwarts, guests (4 VMs + 1 LXC, all `onboot: 1`), NIC offloads still off, API, nodes Ready; **uncordons** (nodes stay cordoned across the reboot); waits (up to 20 min) for all pods to be Running/Completed, then reports leftovers and a Longhorn volume summary. |

## Why not a plain drain
Longhorn's `instance-manager` PDBs allow 0 disruptions, so `kubectl drain` always stalls on them (first attempt, 2026-11-10: ~5 min per node, then the playbook moved on and powered off workers with volumes possibly attached). Now they are excluded from the drain and the playbook refuses to continue until all volumes are detached. The drain uses `--disable-eviction` because other Longhorn PDBs (csi-provisioner) also deadlock once replacements are Pending (seen on the 2nd attempt). Cordon + drain also stops Flux and operators (they sit Pending), so nothing recreates workloads. `startup.yml` uncordons and everything comes back.

## Before
- Expect downtime: public ingress (eero forwards to `.29`) is gone, and `chimaera` is being reinstalled so nothing else carries it.
- Check Longhorn is healthy (no degraded/rebuilding volumes): `kubectl --context prod-gen3 -n longhorn-system get volumes.longhorn.io`.
- Keep the NAS (`room_of_requirement`, Redis/Postgres/NFS) and `bananapi` (Pi-hole) up; k3s and its apps need them at boot. Boot order matters only for these.

## After moving
- Same MAC and eero DHCP reservation keep `192.168.4.196`; if the switch port or cable changed, check link/speed (e1000e `nic0` hang history: `docs/incidents/2026-11-07-hogwarts-e1000e-tx-hang.md`).
- Use the BIOS "restore on AC power" = on if it should boot unattended; otherwise press the power button.

## Verified 2026-11-10 (first real run)
Shutdown took 3 attempts (see "Why not a plain drain"); startup worked. Cold boot expectation: Longhorn `longhorn-csi-plugin` pods crash-loop for ~10 min after boot (CSI socket not up when sidecars start; self-heals), so volume-backed pods (Harbor, media, ARC cache) are late. One volume (`pvc-5f95aa82…`) was already degraded (replica lived on the detached chimaera worker).

## Required variables
| Variable | From |
|---|---|
| `inventoryPasswords.hogwarts` | vault (`-e @./vault.yml`) |
| `confirm_shutdown` | `-e` on the command line (shutdown only) |
| controller-1 access | key auth as `firebolt` (`inventories/gen3`) |
