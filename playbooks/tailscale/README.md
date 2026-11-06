# playbooks/tailscale

Tailscale on the homelab, for remote access to home services while away. It replaces the WireGuard setup in `vpn/`.

- `bananapi` is a **subnet router**: it advertises `192.168.4.0/22` (192.168.4.0-192.168.7.255), so the whole LAN is reachable from the tailnet.
- `bananapi` is also the Pi-hole DNS server (see `dns/`), so while connected you can resolve `<service>.local.abbottland.io` names.
- `marauders_map` is a plain tailnet node. The usual flow is: connect to Tailscale, then SSH to it.
- IPv4 only. Do not add IPv6 config.

## Playbooks

Run from the repo root (inventory defaults to `physical`):

```sh
ansible-playbook -e @./vault.yml playbooks/tailscale/main.yml
```

| File | Hosts | What it does |
|---|---|---|
| `main.yml` | `marauders_map`, `bananapi` | Removes the dead `bullseye-backports` apt source on Debian bullseye, then applies the `artis3n.tailscale` role (native install, systemd), joining the tailnet with a vault authkey. |

State: run in June 2026 (see git history) and not changed since. Not re-verified; the subnet route and DNS-over-tailnet have not been tested end to end.

## Why things are the way they are

- **Subnet routing via `tailscale_args`.** `--advertise-routes=192.168.4.0/22` is set in `inventories/physical/host_vars/bananapi.yml`; only `bananapi` has it.
- **bananapi as the router.** It is the always-on low-power device that already serves DNS.
- **Role pinned to v4.6.0** in `requirements.yml`. v5+ needs ansible-core 2.18.
- **bullseye-backports pre-task.** The apt source is dead on Debian bullseye and breaks the role's apt update.

## Required variables

| Variable | From |
|---|---|
| `tailscale.authkey` | vault (reusable authkey) |
| `tailscale_args` | `inventories/physical/host_vars/bananapi.yml` |
| connection passwords | vault (`inventoryPasswords.*`, via `-e @./vault.yml`) |

Role: `artis3n.tailscale` (pinned in `requirements.yml`, installed by `scripts/setup.sh`).

## TODO / open questions

- Document the admin-console side: approving the `192.168.4.0/22` route, ACLs, and DNS (does the tailnet use bananapi as a nameserver for `local.abbottland.io`?).
- Authkey: expiry and rotation are undocumented.
- Is `marauders_map` needed on the tailnet? Its address is inside the advertised route, so SSH may work through bananapi alone (Linux clients need `--accept-routes`).
- Verify the playbook end to end and test remote access to the LAN.
- Decide whether to delete `vpn/` now that this replaces it.
