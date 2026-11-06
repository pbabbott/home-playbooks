# Playbooks

Run from the repo root. Add `-e @./vault.yml`. Inventory defaults to `inventories/physical`.

| Dir | Purpose | Inventory |
|---|---|---|
| `kubernetes-gen2/` | Bootstrap gen2 k8s nodes. `main.yml` runs 00–05; `06-kubelet` and `07-flux-operator` are not in `main.yml` (unconfirmed if intentional) | `-i inventories/prod` or `nonprod` |
| `shutdown/` | Shut down VMs/hosts (respects `shutdown_exempt`) | prod/nonprod |
| `dns/` | Pi-hole on bananapi | physical |
| `prometheus/` | node_exporter / windows_exporter | physical |
| `tailscale/` | Tailscale on marauders_map, bananapi | physical |
| `proxmox-host/` | Disk / power tuning on `chimaera` (see its README) | physical |
| `ansible-template-ubuntu-noble/` | Build the Ubuntu VM template (see its README) | physical |

Pending review (candidates for removal, untouched since 2024–25): `debug/`, `host_updates/`, `ping/`, `redis/`, `vpn/`, `workstation/`, `pironman/`.
