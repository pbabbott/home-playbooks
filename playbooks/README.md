# Playbooks

Run from the repo root. Add `-e @./vault.yml`. Inventory defaults to `inventories/physical`.

| Dir | Status | Summary | Inventory |
|---|---|---|---|
| `kubernetes-gen2/` | live | Installs kubeadm k8s on the Terraform-created VMs of the gen2 prod/non-prod clusters, then bootstraps Flux so `home-kubernetes` takes over. `main.yml` runs 00–07 in order. Non-prod is currently powered off. | `-i inventories/prod` or `nonprod` |
| `dns/` | live | Pi-hole (Docker) on `bananapi`, the homelab DNS. Opt-in per device; also serves `*.local.abbottland.io`. | physical |
| `tailscale/` | live | Remote access. `bananapi` is a subnet router for `192.168.4.0/22`; `marauders_map` is a plain node. Replaced WireGuard. | physical |
| `redis/` | live | Shared Redis (Docker) on the NAS `room_of_requirement`, no auth by design (LAN only). Harbor is the first consumer. | physical |
| `prometheus/` | live, incomplete | node_exporter / windows_exporter on physical hosts. Prometheus itself lives in `home-kubernetes`; nothing here configures it. | physical |
| `workstation/` | live | DNS + Docker on `marauders_map`, the hand-made dev VM. | physical |
| `k3s-template/` | new | Provisions the gen3 k3s node template `901` on `hogwarts` (run by Packer from `packer/k3s-template/`). | none (Packer) |
| `ansible-template-ubuntu-noble/` | legacy | Builds Proxmox VM template `901` (Ubuntu 24.04) on `chimaera`; gen2 VMs are cloned from it. Reference for gen3. | physical |
| `proxmox-chimaera/` | legacy | One-shot SSD/power tuning for `chimaera` only (not `hogwarts`); kept to document its disk layout. No `main.yml`. | physical |
| `shutdown/` | unfinished | Power off k8s nodes ahead of an outage. Not verified against the current fleet. | prod/nonprod |
| `host_updates/` | unfinished | Apt upgrades for `dumbledore` and `bananapi` with Pushover notifications. Untouched since Jan 2024. | physical |
| `pironman/` | partly working | SunFounder Pironman case (LCD + LED) on `dumbledore`; LED color driven from a k8s API. `change_color.yml` broken. | physical |
| `ping/` | unreviewed | Connectivity checks; no README. | physical |

`host_updates/`, `ping/` and `pironman/` are candidates for removal (untouched since 2024–25).

## Hosts

Which machine does what: [`docs/HOSTS.md`](../docs/HOSTS.md).

## Conventions

- Every playbook dir should have a `main.yml` that just works end-to-end (imports the split playbooks in order). Not all do yet.
- Splitting into smaller playbooks is deliberate: during development of big playbooks, a full run takes a long time, so run the pieces individually.
- Every playbook dir README has a **Required variables** section (name, and where it comes from: inventory vars or vault).
- **This index is the overview.** Every playbook dir gets a row here with its status and a one-to-two sentence summary, and the row is updated whenever the dir's README changes meaningfully (new dir, status change, new host). A reader should know from this file alone which dir to open.
