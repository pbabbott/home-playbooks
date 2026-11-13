# playbooks/prometheus

Installs metrics exporters on the physical hosts so Prometheus can scrape basic health data: CPU, memory, disk and temperature.

- Prometheus itself runs in `home-kubernetes` (https://prometheus.local.abbottland.io/). **Nothing here configures the server or its scrape targets.**
- The metrics feed `home-hud`, a site in the cluster that shows the health of the infra on screen.
- Intent: cover **all physical machines**. Not complete yet (see TODOs).

## Playbooks

Run from the repo root (inventory defaults to `physical`):

```sh
ansible-playbook -e @./vault.yml playbooks/prometheus/main.yml
```

| File | Hosts | What it does |
|---|---|---|
| `main.yml` | | Imports the two playbooks below, in order. |
| `metrics_node_exporter.yml` | `room_of_requirement` (NAS) | node-exporter in Docker (`quay.io/prometheus/node-exporter:latest`, :9100, host rootfs mounted read-only). |
| | `bananapi`, `chimaera`, `hogwarts`, `marauders_map` | `prometheus.prometheus.node_exporter` role (native, systemd). |
| `metrics_windows_exporter.yml` | `elder_wand` (Windows, WinRM) | `windows_exporter` via Chocolatey on :9182; thermalzone collector enabled; firewall rule allowing TCP 9182 from 192.168.4.0/22 on the private profile. |

State: these were run recently and work. They are simple enough to trust, but incomplete in host coverage.

## Why things are the way they are

- **Docker on the NAS.** It is an Asustor NAS with few basic tools, and running the exporter natively hit too many snags. The role also requires systemd. Docker is the working path for Asustor services; a native install would be nicer someday.
- **Windows firewall rule.** The Windows machine blocked everything by default, so the rule is an enablement for the internal network, not a restriction. (`192.168.4.0/22` covers 192.168.4.0-192.168.7.255.)
- **Firewall rule applies to all profiles.** It was Private-only, but Windows can re-categorize the Ethernet NIC as Public after network/adapter changes, which silently dropped scrapes (timeouts on :9182 while WinRM still worked; seen 2026-11-11). The source is still limited to the LAN range.
- **windows_exporter instead of node_exporter.** node_exporter needs systemd; `elder_wand` is Windows.

## Required variables

None are defined in this directory. Anything secret comes from the vault (`-e @./vault.yml`): connection passwords for the hosts come from `inventories/physical/hosts.yml` (`inventoryPasswords.*`). Everything else is inline in the plays.

Collections (pinned in `requirements.yml`, installed by `scripts/setup.sh`): `prometheus.prometheus`, `community.docker`, `community.windows`, `ansible.windows`, `chocolatey.chocolatey`.

## TODO / open questions

- Cover every physical machine. Not yet decided or tested for hosts such as `dumbledore`; the host list may be missing others.
- Verify `main.yml` end to end (just created; the two imported playbooks were run individually).
- Pin the node-exporter image instead of `:latest`.
- node-exporter on :9100 has no firewall restriction on the Linux hosts; confirm that is intended.
- Native exporter on the NAS, if it can be made to work.
- Document how scrape targets are configured in `home-kubernetes`, so adding a host here also gets it scraped.
