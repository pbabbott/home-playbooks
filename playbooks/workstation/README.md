# playbooks/workstation

Base setup for `marauders_map`, the dev/workstation VM (Ubuntu 24, 192.168.5.91): DNS and Docker.

- `marauders_map` is hand-made (not in Terraform). Reach it over SSH, from the LAN or through Tailscale (see `tailscale/`).
- IPv4 only. Do not add IPv6 config.

## Playbooks

Run from the repo root (inventory defaults to `physical`):

```sh
ansible-playbook -e @./vault.yml playbooks/workstation/main.yml
```

| File | Hosts | What it does |
|---|---|---|
| `main.yml` | | Imports `dns.yml` then `docker.yml`. |
| `dns.yml` | `marauders_map` | Sets `DNS=192.168.4.144 1.1.1.1` in `/etc/systemd/resolved.conf` (restarts systemd-resolved on change) and ensures the service is enabled. |
| `docker.yml` | `marauders_map` | Installs Docker and grants user access (inline tasks: Docker apt repo, `docker-ce`, `docker` group membership). |

State: run once in 2025-03 and working. `main.yml` itself is new and has not been run end to end.

## Why things are the way they are

- **DNS via Pi-hole with a fallback.** `192.168.4.144` is bananapi's Pi-hole (see `dns/`), so `*.local.abbottland.io` resolves. `1.1.1.1` keeps the VM resolving if Pi-hole is down.
- **Hardcoded DNS addresses.** `primary_dns` and `secondary_dns` are play vars in `dns.yml`, not inventory vars.

## Required variables

None defined here. Connection details come from `inventories/physical/hosts.yml`; the password is vaulted (`inventoryPasswords.kubernetes_node`, via `-e @./vault.yml`).

## TODO / open questions

- Run `main.yml` end to end to verify the imports.
- Move `primary_dns` / `secondary_dns` to inventory vars if they are needed elsewhere.
