# Open questions (temporary — delete once answered)

Answer inline, then delete the item (or the file). Anything deleted stays recoverable at tag `pre-reorg-2026-11`.
Idea: answer these while writing each playbook's README, then prune accordingly.

## Stale playbooks (nothing in the repo references them)

- **`debug/`** (2024-01): scratch plays (test `abbottland.core.debug`, print web_servers vars, test notification). Delete?
- **`host_updates/`** (2024-01): `pi.yml` apt upgrade on dumbledore. Still how you patch, or replaced?
- **`ping/`** (2024-07): linux/sudo/windows connectivity checks; `main.yml` is empty. Keep one generic ping, or delete (`kubernetes-gen2/ping.yml` covers k8s)?
- **`redis/`** (2024-08): Redis on room_of_requirement. Runs in the cluster now?
- **`vpn/`** (2024-03): WireGuard on bananapi. Replaced by `tailscale/`?
- **`workstation/`** (2025-03): DNS + Docker on marauders_map. Still needed? (`docker.yml` is the only user of `abbottland.docker` besides `kubernetes-gen2/01-containerd.yml`.)
- **`pironman/`** (2025-03): Pironman case on dumbledore (tools, LED color, monitor service). Still in use?

## Hosts in `inventories/physical`

Which of these no longer exist or should be dropped?
`ansible-template-ubuntu-noble` (192.168.6.91), `marauders_map` (192.168.5.91), `dumbledore` (192.168.4.157), `room_of_requirement` (192.168.4.124), `elder_wand` (192.168.5.142), `bananapi` (192.168.4.144), `chimaera` (192.168.4.192).

## Other

- `inventories/physical/group_vars/all.yml` holds mostly legacy vars (docker registry, drone, verdaccio). Which are still used (`dns/pihole.yml` and `vpn/` reference some)? Prune the rest?
- `shutdown/main.yaml` targets only the k8s groups; should it also cover physical hosts (it checks `host_type`/`shutdown_exempt`)?
