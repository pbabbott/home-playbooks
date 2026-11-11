# playbooks/ping

Connectivity checks (`ansible.builtin.ping`) against the physical hosts.

**Status: unfinished, unreviewed.** Last touched July 2024. Kept as a starting point for a generic "is everything reachable" check.

| File | Purpose |
|---|---|
| `main.yml` | Imports `linux_hosts.yml`, `sudo_linux_hosts.yml`, `windows.yml` (in that order) |
| `linux_hosts.yml` | Ping `web_servers`, `room_of_requirement`, `chimaera` |
| `sudo_linux_hosts.yml` | Same hosts, ping with sudo |
| `windows.yml` | Ping `elder_wand` over WinRM |
| `k8s_hosts.yml` | Ping the k8s fleets. **Not imported by `main.yml`**: those hosts live in other inventories (`inventories/gen3`); run it with `-i`. |

```sh
ansible-playbook -e @./vault.yml playbooks/ping/main.yml
```

## Required variables

`inventoryPasswords.*` from the vault (SSH/sudo/WinRM passwords in `inventories/physical`).

## TODO

- Decide on one generic ping and drop the rest, or delete the dir.
- Hosts lists are stale (e.g. `dumbledore`, `hogwarts`, `marauders_map` are missing).
