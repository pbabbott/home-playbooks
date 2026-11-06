# Hosts

The homelab's machines and what each does. Source of truth for connection details is
`inventories/physical/hosts.yml` (physical + standalone VMs) and `inventories/{prod,nonprod}` (k8s VMs).
Playbook dirs are in [`playbooks/README.md`](../playbooks/README.md). Keep this file updated when a host is added, removed or changes role.

Network: IPv4 only, LAN `192.168.4.0/22`, local names `*.local.abbottland.io`.

## Physical hosts and standalone VMs (`inventories/physical`)

| Host | IP | Type | Role | Playbooks |
|---|---|---|---|---|
| `chimaera` | 192.168.4.192 | Proxmox host | Runs the prod gen2 k8s cluster and the VM template. Maxed out on resources; single-SSD disk layout is documented only by `proxmox-chimaera/`. | `proxmox-chimaera/`, `ansible-template-ubuntu-noble/` |
| `hogwarts` | TODO | Proxmox host | Second Proxmox host. Not in the Ansible inventory. | none (`proxmox-chimaera/` must NOT be run on it) |
| `bananapi` | 192.168.4.144 | Raspberry Pi | Pi-hole DNS server and Tailscale subnet router (`192.168.4.0/22`). Kept separate from k8s so DNS stays up independently. | `dns/`, `tailscale/`, `prometheus/`, `host_updates/` |
| `dumbledore` | 192.168.4.157 | Raspberry Pi 4 | Pironman case (LCD + LED); LED color driven by a k8s API. | `pironman/`, `prometheus/`, `host_updates/` |
| `room_of_requirement` | 192.168.4.124 | NAS | Durable home for stateful services (shared Redis, Postgres) so clusters can be rebuilt without data loss. Also `nas.local.abbottland.io`. | `redis/`, `prometheus/` |
| `marauders_map` | 192.168.5.91 | VM (hand-made, not Terraform) | Dev/workstation VM. Reach over SSH from LAN or via Tailscale. | `workstation/`, `tailscale/` |
| `elder_wand` | 192.168.5.142 | Windows PC (WinRM) | TODO: role. Marked `shutdown_exempt`. | `prometheus/` (windows_exporter) |
| `ansible-template-ubuntu-noble` | 192.168.6.91 | VM template (Proxmox ID 901) | Source image cloned into k8s node VMs. | `ansible-template-ubuntu-noble/` |

## Kubernetes fleets (`inventories/prod`, `inventories/nonprod`)

Terraform-created Proxmox VMs, groups `kubernetes_controllers` and `kubernetes_workers`. Configured by
`playbooks/kubernetes-gen2/`; workloads are then deployed by Flux from `home-kubernetes`.
Prod runs on `chimaera`. Non-prod is currently powered off (`chimaera` ran out of resources).
