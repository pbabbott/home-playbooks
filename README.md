# home-playbooks
Ansible playbooks, Terraform and Packer builds for the homelab: Proxmox hosts, the k3s cluster, DNS, remote access and the NAS services.

- **Kubernetes (gen3):** a k3s cluster (3 controllers, 3 workers) on Proxmox VMs across `hogwarts` (primary) and `chimaera`. Terraform creates the VMs from Packer-built templates, Ansible installs k3s and bootstraps Flux, and Flux then deploys workloads from the separate `home-kubernetes` repo. The gen2 kubeadm clusters are retired (VMs destroyed 2026-11-10); their playbooks stay for reference.
- **Ingress and DNS:** an HAProxy LXC fronts the cluster (public via Cloudflare + LAN); Pi-hole on `bananapi` serves internal DNS; Tailscale gives remote access. Public DNS records come from `external-dns` in k8s, not from Terraform here.
- **Stateful services:** the NAS `room_of_requirement` holds Redis, Postgres (including all Terraform state), NFS and media, so clusters can be rebuilt without data loss.
- **Day-2 operations:** runbooks as playbooks, e.g. clean power-off and restart of `hogwarts` or `chimaera` and their k3s nodes (`hogwarts-shutdown/`, `chimaera-shutdown/`).
- **Out of scope:** `home_assistant` and the `eero` router are documented but not managed from here.

Network is IPv4 only (LAN `192.168.4.0/22`). Hosts have Harry Potter names; see [`docs/HOSTS.md`](docs/HOSTS.md).

## Start here

- **What playbooks exist and their status:** [`playbooks/README.md`](playbooks/README.md) (index with a summary per dir).
- **What hosts exist and their roles:** [`docs/HOSTS.md`](docs/HOSTS.md).
- **LAN, DHCP (guest) vs static IP ranges:** [`docs/NETWORK.md`](docs/NETWORK.md). Pick new static IPs from there.
- **`hogwarts` disk layout and Proxmox storage pools:** [`docs/HOGWARTS-STORAGE.md`](docs/HOGWARTS-STORAGE.md).
- **Terraform state (where it lives, how to log in, recovery):** [`docs/TERRAFORM-STATE.md`](docs/TERRAFORM-STATE.md). All Terraform state is in NAS Postgres: `source scripts/tfstate-env.sh` before terraform in any root.
- **gen3 k3s VM templates (hogwarts 900/901, chimaera 910/911):** [`packer/k3s-template/README.md`](packer/k3s-template/README.md), provisioning in [`playbooks/k3s-template/`](playbooks/k3s-template/README.md).
- **Connection details / vars:** `inventories/` (see Layout below).
- **Past work:** `docs/` (plans, runbooks, incidents).

## Layout

| Path | Purpose |
|---|---|
| `inventories/prod`, `inventories/nonprod` | Terraform-managed gen2 k8s VMs (`kubernetes_controllers`, `kubernetes_workers`) |
| `inventories/physical` | Physical hosts + standalone VMs (proxmox `chimaera`, `bananapi`, `dumbledore`, ...). Default inventory in `ansible.cfg`. Holds `group_vars/` and `host_vars/` |
| `playbooks/` | Playbooks, one dir per concern — see [`playbooks/README.md`](playbooks/README.md) |
| `requirements.yml` | Pinned third-party roles + collections |
| `.ansible/` (gitignored) | Installed Galaxy roles/collections |
| `terraform/` | Proxmox VMs (`chimaera/`, `hogwarts/`) + Cloudflare (`cloudflare/`) (see `terraform/README.md`; state: `docs/TERRAFORM-STATE.md`) |
| `packer/` | VM template builds (`k3s-template/` → hogwarts template 901) |
| `vault.yml` | Encrypted secrets (`inventoryPasswords.*`, ...) |
| `docs/` | Host roles (`HOSTS.md`), LAN/DHCP layout (`NETWORK.md`), Terraform state (`TERRAFORM-STATE.md`), plans, runbooks, incidents. `docs/ARCHIVE.md` lists removed code and the tags that preserve it |

## Setup

Requires python3, `ansible-core` (2.17 in the devcontainer), `paramiko`, `pywinrm`, `sshpass`.

```sh
./scripts/setup.sh        # installs pinned roles + collections into .ansible/
./scripts/vault-pass.sh   # writes vault_pass.txt from 1Password (item ansible_vault_pass, Homelab vault)
```

To update a dependency: bump its version in `requirements.yml`, re-run `scripts/setup.sh`.

## Running

Most playbooks need vault vars (`alias apv="ansible-playbook -e @./vault.yml"`):

```sh
# physical hosts (default inventory)
ansible-playbook -e @./vault.yml playbooks/dns/pihole.yml
# k8s fleets
ansible-playbook -e @./vault.yml -i inventories/prod playbooks/kubernetes-gen2/main.yml
```

Use `scripts/vault-protect.sh` / the `encrypt`/`decrypt` aliases for `vault.yml`.

## Windows hosts
`elder_wand` is managed over WinRM (see its vars in `inventories/physical/hosts.yml`).
