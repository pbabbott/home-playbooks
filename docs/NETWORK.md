# Network

LAN addressing as configured in the eero router (`192.168.4.1`, not managed by Ansible). Host IPs are in
[`HOSTS.md`](HOSTS.md). Update this file if the eero settings change.

## eero settings

| Setting | Value |
|---|---|
| IP address prefix | `192.168.0.0/16` (private range the eero draws its subnet from) |
| Subnet | `192.168.4.0`, mask `255.255.252.0` (`/22`) |
| DHCP lease range | `192.168.4.20` – `192.168.5.254` |

The prefix was first noted as `196.168.0.0/16`. That is almost certainly a typo for `192.168.0.0/16`, since `196.x` is public address space. Re-check the eero app if in doubt.

## How to read it

- **Prefix `/16`** is the outer private block (`192.168.0.0`–`192.168.255.255`). The eero only uses a slice of it.
- **Subnet `/22`** is the real LAN: `192.168.4.0` – `192.168.7.255`, 1024 addresses. Gateway is `192.168.4.1`, broadcast `192.168.7.255`.
  `/22` means the third octet spans 4 values (4, 5, 6, 7), so all of `192.168.4.x`–`192.168.7.x` are on one L2 network and reach each other without routing.
- **Lease range** is the dynamic DHCP pool: `192.168.4.20`–`192.168.4.255` plus `192.168.5.0`–`192.168.5.254` (491 addresses).

## Intent: two kinds of address space

| Space | Range | Purpose |
|---|---|---|
| **Guest / DHCP** | `192.168.4.20` – `192.168.5.254` | Dynamic leases for devices that join the house wifi (phones, laptops, visitors). Nothing here is meant to be permanent |
| **Static** | everything else in the `/22`: `192.168.4.1`–`4.19`, `192.168.5.255`, `192.168.6.0`–`6.255`, `192.168.7.0`–`7.254` | Addresses I assign on purpose to infrastructure (k8s nodes, HAProxy, templates, servers). DHCP never hands these out, so they can't collide with a guest |

**Rule: new infrastructure gets a static address from the static space, preferably `192.168.6.x` (gen2 fleet) or `7.x` (free).** Don't pick an address inside the DHCP pool.

## Current allocations

| Range | Use |
|---|---|
| `192.168.4.1` | eero gateway |
| `192.168.6.24` – `6.27` | gen2 prod k8s (controller `.24`, workers `.25`–`.27`) |
| `192.168.6.28` | HAProxy LXC |
| `192.168.6.31` – `6.34` | gen2 non-prod k8s (powered off) |
| `192.168.6.91` | VM template (gen2, chimaera) |
| `192.168.6.250` | Packer build VM for gen3 template 901 (temporary; only exists during `packer build`) |
| `192.168.6.251` – `6.252` | Template verify clones (temporary; only exist during `scripts/verify-k3s-template.sh`) |
| `192.168.7.x` | Unused |

**Legacy exception:** the physical hosts, `elder_wand` and `marauders_map` predate this split and sit inside the DHCP pool
(`chimaera` `4.192`, `hogwarts` `4.196`, NAS `4.124`, `bananapi` `4.144`, `dumbledore` `4.157`, `elder_wand` `5.142`, `marauders_map` `5.91`).
They keep their address only through eero DHCP reservations. If a reservation is lost, a guest device can be given that address.
Moving them into the static space would need their eero reservations, DNS records, and any hardcoded references (for example `ssh root@192.168.4.192`) updated.
