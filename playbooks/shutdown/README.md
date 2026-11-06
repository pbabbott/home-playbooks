# playbooks/shutdown

Powers off the k8s nodes (`kubernetes_workers` and `kubernetes_controllers`) ahead of an expected power outage / UPS event.

> **Status: unfinished. Do not rely on it.** Not verified against the current fleet.

## Playbooks

Run from the repo root. Pick the cluster with `-i`; the default `physical` inventory has no k8s groups, so it targets nothing.

```sh
ansible-playbook -e @./vault.yml -i inventories/nonprod playbooks/shutdown/main.yaml
ansible-playbook -e @./vault.yml -i inventories/prod playbooks/shutdown/main.yaml
```

| File | Hosts | What it does |
|---|---|---|
| `main.yaml` | `kubernetes_workers`, `kubernetes_controllers` | Calls `community.general.shutdown` on every node, skipping any host with `shutdown_exempt` defined. Separate tasks for `host_type == "virtual"` and `"physical"`. |

Scope is the k8s fleet only. All k8s nodes in prod/nonprod are `host_type: virtual`, so the `physical` task and `shutdown_exempt` (set only on `elder_wand` in `inventories/physical`) never apply.

## Known problems

- **No ordering or draining.** Workers and controllers go down in the same play, with no cordon/drain first. See `.claude/skills/drain-reboot` for the safe rolling-reboot approach.
- Dead code: the `physical` task and `shutdown_exempt` check do nothing for k8s-only scope.
- File is `main.yaml`; the other dirs use `main.yml`.
- IPv4 only. Do not add IPv6 config.

## Required variables

| Variable | From |
|---|---|
| `host_type` | per-host in `inventories/{prod,nonprod}/hosts.yml` |
| `shutdown_exempt` | optional, per-host (presence is enough, any value) |
| connection passwords | vault (`inventoryPasswords.*`, via `-e @./vault.yml`) |

Collection: `community.general` (pinned in `requirements.yml`).

## TODO / open questions

- Order the shutdown: drain, workers first, controllers last.
- Remove the `physical` task and `shutdown_exempt`, or give them a real target.
- Document recovery: how the fleet is powered back on (manual today, not written down).
- Decide whether it should also cover physical hosts (NAS, etc.) for an outage.
- Verify against the current fleet.
