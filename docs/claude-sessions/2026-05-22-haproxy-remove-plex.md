# 2026-05-22 — Remove Plex from HAProxy

## What we did

Removed all Plex references from the HAProxy terraform module and applied the change.

## Changes

- `terraform/modules/haproxy/haproxy.cfg` — deleted `frontend frontend-plex` block (port 8022 TCP/SNI frontend); updated stale comment in `frontend-https` that referenced it
- `terraform apply` — pushed updated config to LXC 208 (192.168.6.28), haproxy validated and restarted successfully

## Commit

`4840bb0` — `chore(haproxy): remove plex frontend on :8022`
