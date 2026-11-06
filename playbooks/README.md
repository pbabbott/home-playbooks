# Playbooks

Run from the repo root. Add `-e @./vault.yml`. Inventory defaults to `inventories/physical`.

| Dir | Purpose | Inventory |
|---|---|---|
| `kubernetes-gen2/` | Bootstrap gen2 k8s nodes. `main.yml` runs 00–07 in order | `-i inventories/prod` or `nonprod` |
| `shutdown/` | Shut down VMs/hosts (respects `shutdown_exempt`) | prod/nonprod |
| `dns/` | Pi-hole on bananapi (see its README) | physical |
| `prometheus/` | node_exporter / windows_exporter | physical |
| `tailscale/` | Tailscale on marauders_map, bananapi | physical |
| `proxmox-host/` | Disk / power tuning on `chimaera` (see its README) | physical |
| `ansible-template-ubuntu-noble/` | Build the Ubuntu VM template (see its README) | physical |

Pending review (candidates for removal, untouched since 2024–25): `host_updates/`, `ping/`, `redis/`, `vpn/`, `workstation/`, `pironman/`.

## Conventions

- Every playbook dir should have a `main.yml` that just works end-to-end (imports the split playbooks in order). Not all do yet.
- Splitting into smaller playbooks is deliberate: during development of big playbooks, a full run takes a long time, so run the pieces individually.
- Every playbook dir README has a **Required variables** section (name, and where it comes from: inventory vars or vault).
