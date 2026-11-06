# Playbook review (temporary — delete after decisions)

Fill in the **Your call** column (keep / delete / move / notes). Everything deleted stays recoverable at tag `pre-reorg-2026-11`.
Nothing outside each dir references these playbooks (checked with `git grep`).

| Dir | Last touched | What it does | Targets | Notes from me | Your call |
|---|---|---|---|---|---|
| `debug/` | 2024-01 | 4 scratch plays: test `abbottland.core.debug` role, print web_servers group vars, send a test notification | bananapi, web_servers, dumbledore | Pure scratch/testing. `abbottland_collection_test.yml` is the only thing exercising `abbottland.core.debug`. | |
| `host_updates/` | 2024-01 | `pi.yml`: apt update/upgrade | dumbledore | Superseded by whatever you do now for patching? | |
| `ping/` | 2024-07 | Connectivity checks: linux (plain + sudo), windows (elder_wand), `main.yml` is empty | web_servers, elder_wand | `kubernetes-gen2/ping.yml` already covers k8s. Could keep just one generic ping. | |
| `redis/` | 2024-08 | Set up Redis | room_of_requirement | Pre-k8s style app install; probably runs in the cluster now? | |
| `vpn/` | 2024-03 | Set up WireGuard | bananapi | Tailscale (`playbooks/tailscale`) now runs on bananapi with subnet routing. Replaced? | |
| `workstation/` | 2025-03 | `dns.yml`: set DNS on Ubuntu 24 VM; `docker.yml`: install Docker | marauders_map | `docker.yml` is the only user of `abbottland.docker` besides `kubernetes-gen2/01-containerd.yml`. Is marauders_map still a thing? (tailscale + node_exporter also target it) | |
| `pironman/` | 2025-03 | Pironman case on dumbledore: tools install, LED color, monitor service + script | dumbledore | Keep if the Pironman case is still in use. | |

## Hosts in `inventories/physical` — still real?

| Host | IP | Used by | Your call |
|---|---|---|---|
| `ansible-template-ubuntu-noble` | 192.168.6.91 | template build playbooks | |
| `marauders_map` | 192.168.5.91 | tailscale, node_exporter, workstation | |
| `dumbledore` | 192.168.4.157 | pironman, host_updates, debug | |
| `room_of_requirement` | 192.168.4.124 | prometheus node_exporter, redis | |
| `elder_wand` | 192.168.5.142 | windows_exporter, ping, shutdown-exempt | |
| `bananapi` | 192.168.4.144 | dns (pihole), tailscale, vpn | |
| `chimaera` | 192.168.4.192 | proxmox-host, templates, node_exporter | |
