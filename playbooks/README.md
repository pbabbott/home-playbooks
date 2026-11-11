# Playbooks

Ansible part of the repo. Run everything from the repo root, not from here.

## Setup

Requires python3, `ansible-core` (2.17 in the devcontainer), `paramiko`, `pywinrm`, `sshpass`.

```sh
./scripts/setup.sh        # installs pinned roles + collections into .ansible/
./scripts/vault-pass.sh   # writes vault_pass.txt from 1Password (item ansible_vault_pass, Homelab vault)
```

To update a dependency: bump its version in `requirements.yml`, re-run `scripts/setup.sh`.

## Running

Most playbooks need vault vars: add `-e @./vault.yml` (`alias apv="ansible-playbook -e @./vault.yml"`). Inventory defaults to `inventories/physical`.

```sh
# physical hosts (default inventory)
ansible-playbook -e @./vault.yml playbooks/dns/pihole.yml
# gen3 k3s fleet
ansible-playbook -e @./vault.yml -i inventories/gen3 playbooks/kubernetes-gen3/main.yml
```

Use the `encrypt`/`decrypt` aliases (devcontainer) for `vault.yml`; a pre-commit hook rejects commits with it unencrypted.

`elder_wand` (Windows) is managed over WinRM; see its vars in `inventories/physical/hosts.yml`.

## Playbook index

| Dir | Status | Summary | Inventory |
|---|---|---|---|
| `kubernetes-gen2/` | retired | Installed kubeadm k8s on the gen2 prod/non-prod clusters (VMs destroyed 2026-11-10), then bootstrapped Flux. Reference only; its inventories were removed. | none (removed) |
| `kubernetes-gen3/` | 00–05 run (cluster up, Flux bootstrapped; podinfo only) | k3s on hogwarts + chimaera VMs (3 controllers, 3 workers): DNS, Longhorn disk, k3s server/agents, Calico, CoreDNS custom, Flux Operator. See its README. | `-i inventories/gen3` |
| `time-server/` | new | Makes hogwarts serve NTP (chrony `allow 192.168.4.0/22`) to the LAN; k3s nodes use it first. | `-i inventories/physical -e @./vault.yml` |
| `dns/` | live | Pi-hole (Docker) on `bananapi`, the homelab DNS. Opt-in per device; also serves `*.local.abbottland.io`. | physical |
| `tailscale/` | live | Remote access. `bananapi` is a subnet router for `192.168.4.0/22`; `marauders_map` is a plain node. Replaced WireGuard. | physical |
| `redis/` | live | Shared Redis (Docker) on the NAS `room_of_requirement`, no auth by design (LAN only). Harbor is the first consumer. | physical |
| `prometheus/` | live, incomplete | node_exporter / windows_exporter on physical hosts. Prometheus itself lives in `home-kubernetes`; nothing here configures it. | physical |
| `workstation/` | live | DNS + Docker on `marauders_map`, the hand-made dev VM. | physical |
| `k3s-template/` | live | Provisions the gen3 k3s node template `901` on `hogwarts` (run by Packer from `packer/k3s-template/`). | none (Packer) |
| `ansible-template-ubuntu-noble/` | legacy | Builds Proxmox VM template `901` (Ubuntu 24.04) on `chimaera`; gen2 VMs are cloned from it. Reference for gen3. | physical |
| `proxmox-chimaera/` | legacy | One-shot SSD/power tuning for `chimaera` only (not `hogwarts`); kept to document its disk layout. No `main.yml`. | physical |
| `hogwarts-shutdown/` | live (run 2026-11-10) | Clean power-off of `hogwarts` for a physical move (etcd snapshot, cordon/drain, ordered guest shutdown, poweroff) and `startup.yml` to verify, uncordon and wait for pods afterwards. | physical + gen3 (`-i` both) |
| `chimaera-shutdown/` | live (run 2026-11-11) | Clean power-off of `chimaera` for a physical move (cordon/drain worker-3 + controller-3, Longhorn gate, ordered VM shutdown, poweroff) and `startup.yml` to verify, uncordon worker-3 and wait for rebuilds. Rest of gen3 stays up. | physical + gen3 (`-i` both) |
| `proxmox-no-nag/` | live (run 2026-11-11) | Removes the "no valid subscription" popup on `chimaera` + `hogwarts`: patches `proxmoxlib.js` (re-applied by an apt hook), disables enterprise repos, enables `pve-no-subscription`. | physical |
| `host_updates/` | unfinished | Apt upgrades for `dumbledore` and `bananapi` with Pushover notifications. Untouched since Jan 2024. | physical |
| `pironman/` | partly working | SunFounder Pironman case (LCD + LED) on `dumbledore`; LED color driven from a k8s API. `change_color.yml` broken. | physical |
| `ping/` | unfinished | Connectivity checks (linux, sudo, windows; `k8s_hosts.yml` not imported). Untouched since July 2024. | physical |

`host_updates/`, `ping/` and `pironman/` are unfinished; kept on purpose (see each README).

## Hosts

Which machine does what: [`docs/HOSTS.md`](../docs/HOSTS.md).

## Conventions

- Every playbook dir should have a `main.yml` that just works end-to-end (imports the split playbooks in order). Not all do yet.
- Splitting into smaller playbooks is deliberate: during development of big playbooks, a full run takes a long time, so run the pieces individually.
- Every playbook dir README has a **Required variables** section (name, and where it comes from: inventory vars or vault).
- **This index is the overview.** Every playbook dir gets a row here with its status and a one-to-two sentence summary, and the row is updated whenever the dir's README changes meaningfully (new dir, status change, new host). A reader should know from this file alone which dir to open.
