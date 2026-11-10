## Operational Guidelines

Be brief.

## Reference

- Legacy `archive/` (old per-app Ansible playbooks, pre-k8s) was deleted 2026-11-06. See `docs/ARCHIVE.md`; the code lives at git tag `archive-final`.
- `./playbooks/` - Current ansible playbooks (index: `playbooks/README.md`)
- `./inventories/{gen3,physical}` - gen3 k3s fleet and physical hosts (`prod`/`nonprod` are the retired gen2 fleets, VMs destroyed 2026-11-10; default inventory: physical; group/host vars live in `inventories/physical`)
- `./terraform` - one Terraform root per host: `chimaera/` (gen3 controller-3 + worker-3, templates 910/911), `hogwarts/` (gen3: templates 900/901, fleet VMs 210–214), `cloudflare/`; shared `modules/`.
- `./packer/k3s-template/` - Packer build of the gen3 k3s node template (hogwarts VMID 901, clone of 900); end to end: `scripts/build-k3s-template.sh`. Provisioned by `playbooks/k3s-template/`.


### Important playbooks

- `./playbooks/kubernetes-gen2/` - Retired gen2 clusters (VMs destroyed 2026-11-10); kept for reference.
- `./playbooks/kubernetes-gen3/` - k3s bootstrap for the hogwarts fleet (`-i inventories/gen3`; running prod cluster). **Adding/replacing a worker needs manual steps after the plays (Longhorn node label `node.longhorn.io/create-default-disk=true`): see the "After joining a worker" section of its README and `home-kubernetes/docs/ai-reference-gen3-manual-steps.md`.**
- `./playbooks/dns` - These playbooks manage pihole, my preferred dns server.

### Preferences

- IPv4 only. IPv6 doesn't work well on my network and causes problems; the homelab is small and I don't want the complication, so disable IPv6 everywhere (nodes, templates, services) and don't add IPv6 config.

### Infra

Network: LAN `192.168.4.0/22`. DHCP pool `192.168.4.20`–`192.168.5.254` is for guest wifi devices; everything else (e.g. `192.168.6.x`) is static space for infra. Details and allocations: `docs/NETWORK.md`. Pick new static IPs from the static space, never the pool.

Proxmox host can be accessed in this way: `ssh root@192.168.4.192`

`hogwarts` (new primary Proxmox, `ssh root@192.168.4.196`): disk layout and storage pools (`vm-nvme-01`, `vm-nvme-02`) are in `docs/HOGWARTS-STORAGE.md`. Identify drives by serial, not `/dev/nvmeXn1`.

Most `ansible-playbook`/`ansible` commands need vault vars: pass `-e @./vault.yml`. Without it, plays referencing `{{ inventoryPasswords.* }}` or other vaulted vars fail with "undefined variable".

### Cloudflare / Terraform

Terraform state: all roots (`hogwarts/`, `chimaera/`, `cloudflare/`) use a Postgres backend on the NAS. Before any terraform command run `source scripts/tfstate-env.sh` (separate command, not chained) and confirm it succeeded. Details, setup, gotchas, recovery: `docs/TERRAFORM-STATE.md`.

DNS is managed by `external-dns` — do NOT manage DNS records in Terraform Cloudflare resources. Terraform Cloudflare is for everything else (WAF, page rules, zone settings, etc).