# playbooks/dns

Pi-hole (Docker) on `bananapi`, the homelab DNS server.

- `bananapi` is a low-power device kept separate from the k8s clusters and other physical infra, so DNS stays up independently of them.
- **Opt-in DNS:** the wifi router does *not* hand out this DNS server (ad-blocking sometimes gets in the way). The owner sets it manually on their own devices only, not on family devices.
- Also resolves local names like `<service-or-host>.local.abbottland.io`. All records, including physical hosts such as `nas`, come from the k8s `external-dns` (see TODOs).
- IPv4 only. Do not add IPv6 config.

## Playbooks

Run from the repo root (inventory defaults to `inventories/physical`, target host `bananapi`).

| File | Purpose |
|---|---|
| `main.yml` | Imports `custom_docker_network.yml` then `pihole.yml`. Does **not** include backups. |
| `custom_docker_network.yml` | Docker bridge network `custom-dns` (172.31.0.0/24). |
| `pihole.yml` | Creates config dirs, copies `files/pihole/*`, runs Pi-hole via docker compose (DNS on :53, web UI on :8081, container IP 172.31.0.2). Restarts the container when config files change. |
| `pihole_backups.yml` | Installs two daily cron jobs: `pihole_backup.sh` (`pihole -a -t` into `/backups`) and `remove_old_backups.sh` (deletes `pi-hole-*` files older than 30 days in `/mnt/pihole_backups`). |

```sh
ansible-playbook -e @./vault.yml playbooks/dns/pihole.yml
```

> Unverified: last run was a long time ago. See TODOs.

## Files

- `files/pihole/02-internal.conf`: dnsmasq settings (listen address, `dns-forward-max`).
- `files/pihole_backup.sh`, `files/remove_old_backups.sh`: cron scripts.

## Required variables

| Variable | Source |
|---|---|
| `pihole_config_dir`, `pihole_docker_image`, `cron_scripts_dir` | `inventories/physical/host_vars/bananapi.yml` |
| `host_tz` | `inventories/physical/group_vars/all.yml` |
| `host_puid`, `host_pgid` | `inventories/physical/group_vars/web_servers.yml` (`bananapi` is in `web_servers`) |
| `pihole.password` | Vault (`vault.yml`); not yet confirmed. TODO: name it explicitly. |
| `inventoryPasswords.bananapi` | Vault; SSH/sudo password. |
| `pihole_backup_dir` | Play var in `pihole.yml` (`/mnt/pihole_backups`). |

## TODO / open questions

- **Records are owned by external-dns, not this repo.** `pihole.yml` no longer touches `custom.list` (removed 2026-11-13, [#35](https://github.com/pbabbott/home-playbooks/issues/35)): Pi-hole v5 keeps all local DNS records in that file, external-dns writes them via the API, and with `policy=sync` + `registry=noop` it deletes anything it does not own. To add a host record, create a labelled `DNSEndpoint` (or an HTTPRoute for web UIs) in `home-kubernetes`; see the `dns-expert` agent. Running `pihole.yml` is now safe for DNS records, but it still recreates the container with the pinned image and may drift from the live state: use `--check --diff` first.
- Verify the exact working commands; goal is that `main.yml` runs end-to-end.
- Name and locate all vault variables and confirm where each required var comes from.
- **Backups are unfinished, state unknown:** the NFS mount to the NAS (`192.168.4.124:/volume1/Backups/pihole`) is commented out in `pihole.yml`; `pihole_backups.yml` is not in `main.yml`; `pihole_backup.sh` uses `docker exec -it`, which may fail under cron (no TTY). Verify before relying on it.
- Write a restore procedure.
- **Host-level fixes needed on bananapi** (Docker boot/restart failures, NFS backup mount, journald persistence): see [BPI-FIXES-NEEDED.md](BPI-FIXES-NEEDED.md). Not yet applied or put under Ansible.
