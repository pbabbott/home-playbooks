# Template script parity with old notes

This doc maps **docs/my-old-notes.md** to **scripts/create-ubuntu-template.sh** so we keep parity and know what’s optional.

## What the script does (aligned with old notes)

| Old notes step | Script step | Notes |
|----------------|-------------|--------|
| Get cloud image (wget) | Step 1 | Download skipped if local image exists. Ubuntu release via `UBUNTU_RELEASE` (default `jammy`; use `noble` for 24.04). |
| Create VM (qm create) | Step 2 | VMID required as first arg or env. `MEMORY` (default 1024), `CORES` (default 1), `TEMPLATE_NAME`, `STORAGE` via env. |
| Import disk | Step 3 | Same. |
| Set scsihw + scsi0 | Step 4 | Same. |
| Resize disk (+20G) | Step 4b | **Optional.** Set `TEMPLATE_DISK_RESIZE=+20G` (or e.g. `+50G`). Terraform can still set disk size per clone. |
| Cloud-init drive (ide2) | Step 5 | Same. |
| Boot order (scsi0) | Step 6 | Same. |
| Serial + VGA for console | Step 6 | `--serial0 socket --vga serial0` (console-based management). |
| Cloud-init: ciuser, cipassword, ipconfig0, sshkeys | Step 7 | **Optional.** Set `CIUSER`, `CIPASSWORD`, `IPCONFIG0` (default `ip=dhcp`), `SSH_PUBLIC_KEY_PATH` (path on Proxmox host). Terraform overrides sshkeys/ipconfig per clone. |
| qm template | Step 8 | Same. |

## What the script does *not* do (by design)

- **onboot 1** — Old notes set this on the template. Templates are not started; we don’t set it. Set on cloned VMs if you want them to start on host boot.
- **qemu-guest-agent in template** — Old notes: install in each VM after cloning. The script doesn’t boot the template (cloud-init runs only at first boot), so agent is installed in each clone after first boot or via Ansible. Script prints a reminder.

## Env vars (optional)

| Variable | Default | Purpose |
|----------|---------|---------|
| `VMID` | (required as arg or env) | Template VM ID (e.g. 900). |
| `TEMPLATE_NAME` | `ubuntu-cloud` | Name of the template in Proxmox. |
| `STORAGE` | `local-lvm` | Storage for disk and cloud-init. |
| `MEMORY` | `1024` | Template VM memory (MB). |
| `CORES` | `1` | Template VM cores. |
| `UBUNTU_RELEASE` | `jammy` | Ubuntu release: `jammy` (22.04) or `noble` (24.04). |
| `TEMPLATE_DISK_RESIZE` | (unset) | e.g. `+20G` to grow the template disk. |
| `IPCONFIG0` | `ip=dhcp` | Cloud-init network (template default). |
| `CIUSER` | (unset) | Default cloud-init user. |
| `CIPASSWORD` | (unset) | Default cloud-init password. |
| `SSH_PUBLIC_KEY_PATH` | (unset) | Path on Proxmox host to SSH public key file. |

## Example (match old notes: Noble, 4096MB, 4 cores, +20G, cloud-init defaults)

```bash
# From repo root or terraform/
UBUNTU_RELEASE=noble \
MEMORY=4096 \
CORES=4 \
TEMPLATE_DISK_RESIZE=+20G \
CIUSER=firebolt \
SSH_PUBLIC_KEY_PATH=~/id_rsa.pub \
./scripts/create-ubuntu-template.sh 900
```

Don’t put real passwords in the environment; set `CIPASSWORD` only if you’re OK with it being in process list/shell history, or omit and set via Proxmox UI / Terraform per clone.
