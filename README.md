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
- **Terraform how-tos (first-time setup, layout, VM ID/naming conventions, Proxmox storage, Cloudflare API token):** [`terraform/README.md`](terraform/README.md) and [`terraform/docs/`](terraform/docs/).
- **Connection details / vars:** `inventories/` (see Layout below).
- **Runbooks (step-by-step procedures):** [`docs/runbooks/`](docs/runbooks/), e.g. [worker root disk resize](docs/runbooks/2026-07-13-worker-root-disk-resize-32g-60g.md). Shutdown/startup of a Proxmox host is a playbook: `hogwarts-shutdown/`, `chimaera-shutdown/`.
- **Incidents (what broke, why, fix):** [`docs/incidents/`](docs/incidents/), e.g. [hogwarts e1000e TX hang](docs/incidents/2026-11-07-hogwarts-e1000e-tx-hang.md), [etcd fragmentation](docs/incidents/2026-05-10-etcd-fragmentation.md), [thin pool discard](docs/incidents/2026-06-10-thin-pool-discard-not-configured.md).
- **Plans and handoffs (design notes, mostly historical):** [`docs/plans/`](docs/plans/), e.g. [gen3 Flux handover](docs/plans/2026-11-07-gen3-flux-handover.md).
- **Claude session write-ups:** [`docs/claude-sessions/`](docs/claude-sessions/).
- **Removed code and the git tags that preserve it:** [`docs/ARCHIVE.md`](docs/ARCHIVE.md). The retired gen2 cluster is reference only.

## Layout

| Path | Purpose |
|---|---|
| `inventories/physical` | Physical hosts + standalone VMs (`chimaera`, `hogwarts`, `bananapi`, `dumbledore`, ...). Default inventory in `ansible.cfg`. Holds `group_vars/` and `host_vars/` |
| `inventories/gen3` | gen3 k3s fleet (`tf-prod-k3s-*` VMs on hogwarts + chimaera); use with `-i inventories/gen3` |
| `playbooks/` | Playbooks, one dir per concern. Index: [`playbooks/README.md`](playbooks/README.md) |
| `terraform/` | One root per host: `hogwarts/`, `chimaera/` (Proxmox VMs, HAProxy LXC) and `cloudflare/`; shared `modules/`. See `terraform/README.md`; state: `docs/TERRAFORM-STATE.md` |
| `packer/` | VM template builds (`k3s-template/`, gen3 template `901` on hogwarts, `911` on chimaera) |
| `scripts/` | Helpers (setup, vault, Terraform state/tfvars, k3s template build). Run from the repo root; what each does: [`scripts/CLAUDE.md`](scripts/CLAUDE.md) |
| `docs/` | [`HOSTS.md`](docs/HOSTS.md), [`NETWORK.md`](docs/NETWORK.md), [`HOGWARTS-STORAGE.md`](docs/HOGWARTS-STORAGE.md), [`TERRAFORM-STATE.md`](docs/TERRAFORM-STATE.md), plus [`runbooks/`](docs/runbooks/), [`incidents/`](docs/incidents/), [`plans/`](docs/plans/), [`claude-sessions/`](docs/claude-sessions/). [`ARCHIVE.md`](docs/ARCHIVE.md) lists removed code and the tags that preserve it |
| `requirements.yml` | Pinned third-party roles + collections |
| `vault.yml` | Encrypted secrets (`inventoryPasswords.*`, ...) |
| `ansible.cfg` | Default inventory, roles/collections paths, vault password file |
| `.ansible/`, `vault_pass.txt` | Gitignored: installed Galaxy roles/collections, and the vault password written by `scripts/vault-pass.sh` |
| `.devcontainer/`, `.claude/`, `.pre-commit-config.yaml`, `.ansible-lint` | Dev container, Claude Code commands/skills/settings, pre-commit hooks (incl. vault-encryption check), lint config |

## Tooling

The repo mixes three tools. Run each from its own place; setup and usage live next to it.

| Tool | Does | Docs |
|---|---|---|
| Ansible | Configures hosts and installs k3s (`playbooks/`, `inventories/`) | [`playbooks/README.md`](playbooks/README.md): setup, running, vault, Windows hosts |
| Terraform | Creates Proxmox VMs/LXCs and Cloudflare settings (`terraform/`) | [`terraform/README.md`](terraform/README.md); state: `source scripts/tfstate-env.sh` first ([`docs/TERRAFORM-STATE.md`](docs/TERRAFORM-STATE.md)) |
| Packer | Builds the gen3 k3s VM templates (`packer/`) | [`packer/k3s-template/README.md`](packer/k3s-template/README.md) |

Secrets come from 1Password (`op`) via `scripts/`; `vault.yml` holds the Ansible vault. Common workflows (full manifest in [`scripts/CLAUDE.md`](scripts/CLAUDE.md)):

- **First-time setup:** `./scripts/setup.sh`, then `./scripts/vault-pass.sh`.
- **Terraform:** `source scripts/tfstate-env.sh`, then `NODE_ARG=<hogwarts|chimaera> ./scripts/tfvars-node.sh` if `terraform.tfvars` is missing.
- **Rebuild a k3s template:** `./scripts/build-k3s-template.sh [hogwarts|chimaera]`.
