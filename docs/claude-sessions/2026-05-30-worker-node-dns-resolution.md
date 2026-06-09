# 2026-05-30 — Worker Node DNS Resolution for Private Registry

## Problem

Kubernetes worker nodes in prod-gen2 (and nonprod-gen2) could not resolve
`*.local.abbottland.io` hostnames at the OS level. This caused `containerd`
to fail pulling images from the private Harbor registry at
`harbor.local.abbottland.io` (192.168.6.28), producing `ImagePullBackOff`.

Root cause: `containerd` uses the node's system resolver, not in-cluster
CoreDNS. The system resolver had no route to Pihole (192.168.4.144), which
is the authoritative server for `*.local.abbottland.io`.

## Fix

Added a `systemd-resolved` drop-in config on all nodes that routes
`local.abbottland.io` queries specifically to Pihole (split-DNS). Other
resolution is unaffected.

Drop-in file deployed to each node:

```
/etc/systemd/resolved.conf.d/pihole.conf
```

```ini
[Resolve]
DNS=192.168.4.144
Domains=~local.abbottland.io
```

The `~` prefix makes this a routing-only domain — no search suffix behavior.

## Files changed

- `playbooks/kubernetes-gen2/00-dns.yml` — new playbook; creates drop-in dir,
  deploys config, restarts `systemd-resolved`
- `playbooks/kubernetes-gen2/main.yml` — added `00-dns.yml` as first import
  so DNS is configured before containerd or kubelet

## Applied to

- **nonprod**: controller + workers 1–3 (192.168.6.31–.34) — all changed, 0 failures
- **prod**: controller + workers 1–3 (192.168.6.24–.27) — all changed, 0 failures

## Verification

```bash
# Ran on each prod worker after apply
getent hosts harbor.local.abbottland.io
# Result: 192.168.6.28    harbor.local.abbottland.io  ✓
```

## Durability

Fix survives reboots (drop-in file is persistent). If a node is reprovisioned
from template and `main.yml` re-runs, `00-dns.yml` reapplies it automatically.

## Commit

`c3007f0` — feat(k8s): add OS-level DNS resolution for local.abbottland.io
