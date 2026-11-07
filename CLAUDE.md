## Operational Guidelines

Be brief.

## Reference

- Legacy `archive/` (old per-app Ansible playbooks, pre-k8s) was deleted 2026-11-06. See `docs/ARCHIVE.md`; the code lives at git tag `archive-final`.
- `./playbooks/` - Current ansible playbooks (index: `playbooks/README.md`)
- `./inventories/{prod,nonprod,physical}` - k8s gen2 fleets and physical hosts (default inventory: physical; group/host vars live in `inventories/physical`)
- `./terraform` - one Terraform root per host: `chimaera/` (gen2 prod/non-prod vms + ha proxy lxc), `hogwarts/` (gen3, scaffold only), `cloudflare/`; shared `modules/`.


### Important playbooks

- `./playbooks/kubernetes-gen2/` - This is where my current gen2 prod and non-prod clusters are bootstrapped.
- `./playbooks/dns` - These playbooks manage pihole, my preferred dns server.

### Preferences

- IPv4 only. IPv6 doesn't work well on my network and causes problems; the homelab is small and I don't want the complication, so disable IPv6 everywhere (nodes, templates, services) and don't add IPv6 config.

### Infra

Network: LAN `192.168.4.0/22`. DHCP pool `192.168.4.20`–`192.168.5.254` is for guest wifi devices; everything else (e.g. `192.168.6.x`) is static space for infra. Details and allocations: `docs/NETWORK.md`. Pick new static IPs from the static space, never the pool.

Proxmox host can be accessed in this way: `ssh root@192.168.4.192`

`hogwarts` (new primary Proxmox, `ssh root@192.168.4.196`): disk layout and storage pools (`vm-nvme-01`, `vm-nvme-02`) are in `docs/HOGWARTS-STORAGE.md`. Identify drives by serial, not `/dev/nvmeXn1`.

Most `ansible-playbook`/`ansible` commands need vault vars: pass `-e @./vault.yml`. Without it, plays referencing `{{ inventoryPasswords.* }}` or other vaulted vars fail with "undefined variable".

### Cloudflare / Terraform

DNS is managed by `external-dns` — do NOT manage DNS records in Terraform Cloudflare resources. Terraform Cloudflare is for everything else (WAF, page rules, zone settings, etc).