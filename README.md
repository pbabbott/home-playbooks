# home-playbooks
Ansible playbooks (and Terraform) for home infra.

## Start here

- **What playbooks exist and their status:** [`playbooks/README.md`](playbooks/README.md) (index with a summary per dir).
- **What hosts exist and their roles:** [`docs/HOSTS.md`](docs/HOSTS.md).
- **`hogwarts` disk layout and Proxmox storage pools:** [`docs/HOGWARTS-STORAGE.md`](docs/HOGWARTS-STORAGE.md).
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
| `terraform/` | Proxmox VMs (`chimaera/`, `hogwarts/`) + Cloudflare (`cloudflare/`) (see `terraform/README.md`) |
| `vault.yml` | Encrypted secrets (`inventoryPasswords.*`, ...) |
| `docs/` | Host roles (`HOSTS.md`), plans, runbooks, incidents. `docs/ARCHIVE.md` lists removed code and the tags that preserve it |

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
