# Hosts

The homelab's machines and what each does. Source of truth for connection details is
`inventories/physical/hosts.yml` (physical + standalone VMs) and `inventories/{prod,nonprod}` (k8s VMs).
Playbook dirs are in [`playbooks/README.md`](../playbooks/README.md). Keep this file updated when a host is added, removed or changes role.

Network: IPv4 only, LAN `192.168.4.0/22`, local names `*.local.abbottland.io`. guest DHCP vs static ranges and allocations: [`NETWORK.md`](NETWORK.md).

## Physical hosts

| Host | IP | Hardware | Role | Playbooks |
|---|---|---|---|---|
| `chimaera` | 192.168.4.192 | Beelink SER5 mini PC: Ryzen 5 5500U (6C/12T), 64GB DDR4, 1TB NVMe + 2TB SSD | Proxmox host running the prod gen2 k8s cluster and the VM template. Also gen3 k3s controller-3 + worker-3 (VMs 215 `.45` 2c/3 GB and 216 `.46` 4c/6 GB + 100 GB Longhorn disk on `fast-ssd`, `terraform/chimaera/k3s.tf`; root disks on `local-lvm`; sized to the ~12 GB of RAM left beside gen2; PVE 8.2.4 has no `import` content so the base image is an iso-content `.img`). `marauders-map` (VM 500) was shut down 2026-11-07 (it was using little RAM, freed only about 1 GB); k3s templates here are `910` base / `911` (`tpl-k3s-noble`), built with `scripts/build-k3s-template.sh chimaera` (`900`/`901` are the legacy gen2 templates). **Maxed out:** the whole cluster sits on one of its two drives, so parallel docker builds cause IO contention (etcd and Longhorn get unhealthy), and VM CPU competes with the host OS. Disk layout is documented only by `proxmox-chimaera/`. | `proxmox-chimaera/`, `ansible-template-ubuntu-noble/` |
| `hogwarts` | 192.168.4.196 | HP Z2 G1i SFF workstation: Intel Core Ultra 7 265 (20 cores), 64GB RAM, 1TB M.2 + 2x2TB M.2 | New primary Proxmox server that will power k8s gen3. Serves NTP (chrony) to the LAN, `playbooks/time-server/`. Disks and storage pools (`vm-nvme-01`, `vm-nvme-02`): [`HOGWARTS-STORAGE.md`](HOGWARTS-STORAGE.md). | `k3s-template/` (template build via `packer/k3s-template/`). Templates on `local-lvm`: `900` base Ubuntu 24.04, `901` k3s-ready. gen3 fleet VMs 210, 211, 212, 214 (`tf-prod-k3s-*`, `terraform/hogwarts/`): controllers (210, 214) on `local-lvm`, workers on `vm-nvme-01`/`vm-nvme-02`. NIC offloads (TSO/GSO/GRO) are disabled on `nic0` via `hogwarts-network/` after an e1000e TX hang ([incident](incidents/2026-11-07-hogwarts-e1000e-tx-hang.md)). `proxmox-chimaera/` must NOT be run on it |
| `room_of_requirement` | 192.168.4.124 | Asustor NAS | Durable stateful storage: shared Redis and Postgres (clusters point here so they can be rebuilt without data loss), NFS for k8s, mass media (movies, TV), and backups of personal files (wedding photos, video projects). Also `nas.local.abbottland.io`. | `redis/`, `prometheus/` |
| `bananapi` | 192.168.4.144 | Banana Pi BPI-M5 (Amlogic S905X3 SBC), GeeekPi kit with case and fan | Pi-hole DNS server and Tailscale subnet router (`192.168.4.0/22`). Kept separate from k8s so DNS stays up independently. | `dns/`, `tailscale/`, `prometheus/`, `host_updates/` |
| `dumbledore` | 192.168.4.157 | Raspberry Pi 4 Model B, 8GB | **Currently offline.** Plan: join gen3 k8s as a controller for etcd quorum (gen3 etcd is currently 3 members: 2 on `hogwarts`, 1 on `chimaera`; retire `tf-prod-k3s-controller-2` once dumbledore joins), and run light ARM workloads. Also has the Pironman case (LCD + LED), with LED color driven by a k8s API. | `pironman/`, `prometheus/`, `host_updates/` |
| `elder_wand` | 192.168.5.142 | Windows gaming PC | Personal gaming machine, kept clean for games. Its GPU is occasionally used for AI workloads via LM Studio, but nothing else should be put on it. `shutdown_exempt`. Managed over WinRM. | `prometheus/` (windows_exporter) |
| `eero` router | 192.168.4.1 | eero Pro 6E mesh wifi router | Network gateway. Holds the DHCP IP reservations and port-forwards 80/443 to HAProxy (192.168.6.28), which is the ingress for publicly facing workloads. Does not hand out Pi-hole DNS (opt-in per device). Not in Ansible. | none |
| `home_assistant` | 192.168.4.37 | Not documented here (hardware/OS unknown to this repo) | Home Assistant, web UI on port 8123. Not managed by Ansible or Terraform from this repo (the old `home_assistant` playbook is archived, see `ARCHIVE.md`). Reached from k8s as a proxy: the `home-assistant` namespace in `home-kubernetes` (`applications/base/home-assistant`, Service + EndpointSlice to `192.168.4.37:8123`) serves `homeassistant.abbottland.io` publicly through Cloudflare and the Istio public gateway. Update the EndpointSlice if this IP ever changes (it was wrongly `192.168.4.24` until 2026-11-09, which made the public site return 503). | none |

## Virtual hosts

| Host | IP | Runs on | Role | Managed by | Playbooks |
|---|---|---|---|---|---|
| `tf-prod-k8s-controller-1` | 192.168.6.24 | `chimaera` | Prod gen2 k8s control plane | Terraform + Ansible | `kubernetes-gen2/` |
| `tf-prod-k8s-worker-1..3` | 192.168.6.25-27 | `chimaera` | Prod gen2 k8s workers | Terraform + Ansible | `kubernetes-gen2/` |
| `tf-nonprod-k8s-controller-1` | 192.168.6.31 | `chimaera` | Non-prod control plane. **Powered off** (`chimaera` out of resources) | Terraform + Ansible | `kubernetes-gen2/` |
| `tf-nonprod-k8s-worker-1..3` | 192.168.6.32-34 | `chimaera` | Non-prod workers. **Powered off** | Terraform + Ansible | `kubernetes-gen2/` |
| `marauders_map` | 192.168.5.91 | `chimaera` | Dev/workstation VM (Ubuntu 24). Reach over SSH from the LAN or via Tailscale | hand-made | `workstation/`, `tailscale/` |
| `ansible-template-ubuntu-noble` | 192.168.6.91 | `chimaera` | Proxmox VM template (ID 901, Ubuntu 24.04), cloned into k8s nodes | Ansible | `ansible-template-ubuntu-noble/` |
| HAProxy LXC | 192.168.6.28 | `chimaera` | Load balancer (stats page at http://192.168.6.28:8404/). Defined in `terraform/modules/haproxy`, applied from `terraform/chimaera` | Terraform | none |
| HAProxy LXC (gen3) | 192.168.6.29 | `hogwarts` | Ingress for the gen3 k3s workers (NodePorts 30080/30443, PROXY v2); LXC 213, config `terraform/hogwarts/haproxy.cfg`, stats http://192.168.6.29:8404/. Replaces the chimaera one after the eero 80/443 forward is repointed | Terraform | none |

Prod and non-prod k8s workloads are deployed by Flux from `home-kubernetes`.
