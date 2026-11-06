# playbooks/redis

A shared Redis instance (Docker) on `room_of_requirement` (the NAS), for any app in the homelab that needs Redis.

- **Pattern:** databases live on the NAS because it is the most durable place to keep important data. Postgres is shared the same way. Cluster apps point at the NAS instead of running their own stateful store, so clusters can be rebuilt without losing data.
- Harbor (prod and non-prod) was the first consumer; more apps are expected.
- **Live and in use.** Reachable at `nas.local.abbottland.io:6379`.
- **No auth, no TLS, by design:** LAN-only on a trusted network. Do not expose the port beyond it.
- IPv4 only. Do not add IPv6 config.

## Playbooks

Run from the repo root (inventory defaults to `physical`):

```sh
ansible-playbook -e @./vault.yml playbooks/redis/main.yml
```

| File | Hosts | What it does |
|---|---|---|
| `main.yml` | `room_of_requirement` | Creates `redis_data_dir`, then runs `redis:7.4` via `community.docker.docker_compose` (project `redis`, `restart: always`, port 6379, data volume mounted at `/data`). |

## Consumers

| App | Where configured | DB indexes |
|---|---|---|
| Harbor prod | `home-kubernetes/applications/prod-gen2/harbor/kustomization.yaml` | 3, 4, 5, 6, 11, 12 |
| Harbor non-prod | `home-kubernetes/applications/non-prod-gen2/harbor/kustomization.yaml` | 8, 9, 10, 13, 14, 15 |

Base values in `applications/base/harbor/helmrelease.yaml` (0, 1, 2, 5, 6, 7) are the old gen1 defaults, overridden per cluster. Harbor uses six DBs per environment, so prod and non-prod each get their own set to avoid collisions.

## Why things are the way they are

- **On the NAS, not in the cluster.** See the pattern above: durable data lives on the NAS.
- **Docker on the NAS.** The Asustor NAS runs its services in Docker (same as `prometheus/`).
- **Plain defaults.** No password, no config file, no AOF flag: a trusted-LAN cache/queue store, not a hardened service.

## Required variables

| Variable | From |
|---|---|
| `redis_data_dir` | `inventories/physical/host_vars/room_of_requirement.yml` (`/volume1/Docker/redis/data`) |
| `ansible_password`, `ansible_sudo_pass` | vault (`inventoryPasswords.room_of_requirement`) |

Collection: `community.docker` (pinned in `requirements.yml`, installed by `scripts/setup.sh`).

## Verify

```sh
redis-cli -h nas.local.abbottland.io ping    # PONG
```

## TODO / open questions

- **Redis DB indexes are nearly used up.** Redis defaults to 16 DBs (0-15) and Harbor takes 12 of them. A new app should use its own key prefix, a raised `databases` setting, or a second instance, rather than assuming a free DB index.
- Pin to a patch version instead of `redis:7.4` (and decide on an upgrade routine).
- Persistence is whatever the image does by default (RDB snapshots). Decide whether AOF is wanted, and whether the data dir is backed up.
- Not verified end to end since 2024-08 (the playbook was written then; Harbor is what proves it runs).
