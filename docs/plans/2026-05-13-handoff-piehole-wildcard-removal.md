# Handoff: Remove Pihole Wildcard DNS Record

**Repo:** `pbabbott/home-playbooks` (Ansible)  
**Companion repo:** `pbabbott/home-kubernetes` (commit `7b4372c`)

---

## Context

Pihole currently has a wildcard local DNS record:

```
*.local.abbottland.io → 192.168.6.28
```

This wildcard causes Kubernetes pods (default `ndots:5`) to incorrectly resolve
external hostnames like `api.github.com` via the search-domain chain:

```
api.github.com.local.abbottland.io → 192.168.6.28  ← HAProxy ingress, wrong cert
```

This breaks outbound HTTPS and SSH from pods that haven't been patched with `ndots:1`/`ndots:2`.

## What Was Done in home-kubernetes

A new `external-dns-pihole` deployment was added that watches Kubernetes `HTTPRoute`
resources labeled `pihole-dns-enabled=true` and automatically creates **individual A records**
in pihole for each service (e.g. `grafana.local.abbottland.io → 192.168.6.28`).

The wildcard can be removed once `external-dns-pihole` is running and has populated
the individual records.

## Pihole Details

| Field | Value |
|-------|-------|
| Host | `192.168.4.144` |
| Admin port | `8081` |
| Version | v5.18.2 (Docker tag `2024.05.0`) |
| Admin password | In 1Password: `vaults/Homelab/items/pihole.local.abbottland.io (bananapi)` |

Pihole runs on a device called "bananapi" — likely a BananaPi or similar SBC.

## The Change Required

**Remove** the wildcard entry from pihole's local DNS configuration:

```
*.local.abbottland.io  →  192.168.6.28   ← DELETE THIS
```

In pihole v5, local DNS records are stored in `/etc/pihole/custom.list` on the pihole host.
A wildcard entry there looks like:

```
192.168.6.28 *.local.abbottland.io
```

The Ansible task should:
1. Remove that line from `/etc/pihole/custom.list` (or equivalent managed location in this repo)
2. Restart/reload pihole DNS (typically `pihole restartdns` or restarting the `pihole-FTL` service)

## Expected Records AFTER Wildcard Removal

external-dns-pihole will maintain these individual A records automatically.
The wildcard removal should NOT break anything if external-dns is already running.
Verify before removing:

```bash
nslookup grafana.local.abbottland.io 192.168.4.144
nslookup pihole.local.abbottland.io 192.168.4.144
nslookup longhorn.local.abbottland.io 192.168.4.144
```

All should resolve to `192.168.6.28` before removing the wildcard.

## Post-Removal Verification

```bash
# These should all still resolve:
nslookup grafana.local.abbottland.io 192.168.4.144
nslookup harbor.local.abbottland.io 192.168.4.144

# This should return NXDOMAIN (the whole point):
nslookup api.github.com.local.abbottland.io 192.168.4.144
```

## Notes for the AI

- Explore the repo first to find how pihole local DNS is currently managed
  (look for `custom.list`, pihole role/playbook, host vars for `192.168.4.144`)
- The wildcard may be defined as an Ansible variable — remove it from the variable,
  not just the rendered file
- Do not remove any other local DNS records — only the wildcard `*.local.abbottland.io`
- There may also be a `*.local.non-prod.abbottland.io` wildcard — remove that too
  if present (same reasoning applies to the non-prod cluster)
