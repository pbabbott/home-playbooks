# Playbooks

Run from the repo root. Add `-e @./vault.yml`. Inventory defaults to `inventories/physical`.

| Dir | Purpose | Inventory |
|---|---|---|
| `kubernetes-gen2/` | Bootstrap gen2 k8s nodes. `main.yml` runs 00–07 in order | `-i inventories/prod` or `nonprod` |
| `shutdown/` | Power off the k8s nodes ahead of a power outage; unfinished (see its README) | prod/nonprod |
| `dns/` | Pi-hole on bananapi (see its README) | physical |
| `prometheus/` | node_exporter / windows_exporter | physical |
| `redis/` | Shared Redis on the NAS; Harbor is the first consumer (see its README) | physical |
| `tailscale/` | Tailscale on marauders_map, bananapi | physical |
| `proxmox-chimaera/` | Disk / power tuning on `chimaera` only; legacy, kept to document disk layout (see its README) | physical |
| `ansible-template-ubuntu-noble/` | Build the Ubuntu VM template (see its README) | physical |

Pending review (candidates for removal, untouched since 2024–25): `host_updates/`, `ping/`, `vpn/`, `workstation/`, `pironman/`.

## Conventions

- Every playbook dir should have a `main.yml` that just works end-to-end (imports the split playbooks in order). Not all do yet.
- Splitting into smaller playbooks is deliberate: during development of big playbooks, a full run takes a long time, so run the pieces individually.
- Every playbook dir README has a **Required variables** section (name, and where it comes from: inventory vars or vault).
