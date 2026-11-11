# home-playbooks

Ansible, Terraform and Packer for the homelab. Overview and setup: `README.md` ("Start here").

## Layout

| Path | Purpose |
|---|---|
| `playbooks/` | Ansible playbooks, one dir per concern. Index and status: `playbooks/README.md`; key ones listed under Ansible below |
| `inventories/physical` | Physical hosts + standalone VMs. Default inventory; group/host vars live here |
| `inventories/gen3` | gen3 k3s fleet |
| `terraform/` | One root per host: `chimaera/` (gen3 controller-3 + worker-3, templates 910/911), `hogwarts/` (gen3: templates 900/901, fleet VMs 210–214), `cloudflare/`; shared `modules/` |
| `packer/k3s-template/` | Packer build of the gen3 k3s node template (hogwarts VMID 901, clone of 900). End to end: `scripts/build-k3s-template.sh` |
| `scripts/` | Setup, vault, Terraform-state and template-build helpers (see `README.md` Layout) |
| `docs/` | Hosts, network, storage, Terraform state, incidents, plans, runbooks. Removed code: `docs/ARCHIVE.md` (old `archive/` was deleted 2026-11-06; tag `archive-final`) |

## Hosts

Full detail: `docs/HOSTS.md` (keep it updated when hosts change). Hosts have Harry Potter names.

- `hogwarts` (192.168.4.196, `ssh root@192.168.4.196`) - primary Proxmox, gen3. Runs controllers 210/214, workers, HAProxy LXC 213, NTP server, `marauders_map` (off). Disks and storage pools (`vm-nvme-01`, `vm-nvme-02`): `docs/HOGWARTS-STORAGE.md`; identify drives by serial, not `/dev/nvmeXn1`. Never run `proxmox-chimaera/` on it.
- `chimaera` (192.168.4.192, `ssh root@192.168.4.192`) - Proxmox 9.2.2, reinstalled 2026-11-10 (gen2 VMs gone). Runs gen3 controller-3 + worker-3 on its SATA SSD and NVMe; resource-tight.
- `room_of_requirement` (192.168.4.124) - Asustor NAS: shared Redis and Postgres (incl. all Terraform state), NFS, media, backups.
- `bananapi` (192.168.4.144) - Pi-hole DNS and Tailscale subnet router, kept off k8s on purpose.
- `dumbledore` (192.168.4.157) - Raspberry Pi 4, currently offline; planned etcd quorum node for gen3.
- `elder_wand` (192.168.5.142) - Windows gaming PC, managed over WinRM; keep it clean, nothing else on it.
- `marauders_map` (192.168.5.91) - dev VM on hogwarts, powered off.
- HAProxy LXC (192.168.6.29) - gen3 ingress, public + LAN (`terraform/hogwarts/`). The gen2 one (`.28`) is stopped, awaiting removal.
- `home_assistant` (192.168.4.37:8123) and `eero` router (192.168.4.1) - not managed from this repo.

### Virtual hosts: the gen3 k3s cluster

"controller1", "worker3" etc. always mean the gen3 k3s VMs (`tf-prod-k3s-controller-N` / `tf-prod-k3s-worker-N`; the gen2 `tf-*-k8s-*` VMs are gone).

| Short name | VMID | IP | Proxmox host |
|---|---|---|---|
| controller1 (cluster-init) / controller2 | 210 / 214 | 192.168.6.41 / .44 | `hogwarts` |
| controller3 | 215 | 192.168.6.45 | `chimaera` |
| worker1 / worker2 | 211 / 212 | 192.168.6.42 / .43 | `hogwarts` |
| worker3 | 216 | 192.168.6.46 | `chimaera` |

- Created by Terraform (`terraform/hogwarts/`, `terraform/chimaera/`) from the Packer k3s template; configured by `playbooks/kubernetes-gen3/` (`-i inventories/gen3`, user `firebolt`, SSH key, passwordless sudo); workloads come from Flux (`home-kubernetes`).
- Workers carry a Longhorn data disk. controller2 is to be retired once `dumbledore` joins as a controller.
- Day-to-day power-off: `hogwarts-shutdown/` and `chimaera-shutdown/`.

## Network

- LAN `192.168.4.0/22`. DHCP pool `192.168.4.20`-`192.168.5.254` is for guest wifi devices; everything else (e.g. `192.168.6.x`) is static space for infra. Pick new static IPs from the static space, never the pool. Allocations: `docs/NETWORK.md`.
- IPv4 only. IPv6 doesn't work well on my network and causes problems; the homelab is small and I don't want the complication, so disable IPv6 everywhere (nodes, templates, services) and don't add IPv6 config.
- Ingress: eero forwards 80/443 to HAProxy `192.168.6.29`, which fronts the gen3 workers (LAN + Cloudflare IPs only).
- DNS: see the DNS section below.
- Remote access: Tailscale, `bananapi` advertises `192.168.4.0/22`.

## Ansible

Most `ansible-playbook`/`ansible` commands need vault vars: pass `-e @./vault.yml`. Without it, plays referencing `{{ inventoryPasswords.* }}` or other vaulted vars fail with "undefined variable".

Key playbooks (all in `playbooks/`, status of the rest in its README):

- `kubernetes-gen3/` - k3s bootstrap + Flux for the running prod cluster (`-i inventories/gen3`). **Adding/replacing a worker needs manual steps after the plays (Longhorn node label `node.longhorn.io/create-default-disk=true`): see the "After joining a worker" section of its README and `home-kubernetes/docs/ai-reference-gen3-manual-steps.md`.**
- `k3s-template/` - provisions the gen3 node template (run by Packer, `packer/k3s-template/`).
- `dns/` - Pi-hole on `bananapi`, my preferred DNS server.
- `hogwarts-shutdown/`, `chimaera-shutdown/` - clean power-off and restart of a Proxmox host and its k3s nodes.
- `tailscale/`, `redis/`, `time-server/` - remote access, NAS Redis, NTP from hogwarts.

## Terraform

Terraform state: all roots (`hogwarts/`, `chimaera/`, `cloudflare/`) use a Postgres backend on the NAS. Before any terraform command run `source scripts/tfstate-env.sh` (separate command, not chained) and confirm it succeeded. Details, setup, gotchas, recovery: `docs/TERRAFORM-STATE.md`.

`cloudflare/` is for WAF, page rules, zone settings, etc. Do NOT manage DNS records there (see DNS).

## DNS

Two layers, both IPv4 only:

- **Public** (Cloudflare, `abbottland.io`): records are created by `external-dns` from k8s resources in `home-kubernetes`, never by Terraform or by hand. Traffic enters via eero (80/443) to HAProxy `192.168.6.29`, which only accepts LAN + Cloudflare IPs.
- **Internal** (Pi-hole on `bananapi`, `playbooks/dns/`): opt-in per device (eero does not hand it out) and serves `*.local.abbottland.io`. Static host records live in `playbooks/dns/files/pihole/custom.list`; cluster-related entries come from `external-dns`. Remote clients reach it over Tailscale (`bananapi` subnet router).

For questions about how a hostname resolves, why a record is missing or wrong, how to expose an app publicly or on the LAN, or for drafting a new public/internal DNS entry, use the `dns-expert` agent instead of working it out here.

---

*Footnote, gen2 (dead):* my old kubeadm clusters (prod + non-prod, `tf-*-k8s-*` VMs on chimaera) were destroyed 2026-11-10. Their code (`playbooks/kubernetes-gen2/`, `playbooks/ansible-template-ubuntu-noble/`) and the removed-code index (`docs/ARCHIVE.md`) are kept only as reference for legacy questions like "how did this used to work in my old gen2 cluster?". Never build on them or treat them as current; old plans, incidents and session logs in `docs/` are likewise history.
