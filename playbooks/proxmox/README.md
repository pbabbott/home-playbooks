# Proxmox playbooks

Playbooks that run against the Proxmox host(s) (inventory group `proxmox_hosts`).

## create-ubuntu-template.yml

Creates a Proxmox cloud-init template from an Ubuntu cloud image. Same outcome as [terraform/scripts/create-ubuntu-template.sh](../../terraform/scripts/create-ubuntu-template.sh); see [terraform/docs/create-ubuntu-template.md](../../terraform/docs/create-ubuntu-template.md) for details.

**Required:** `vmid` (e.g. 900). Pass with `-e vmid=900`.

**Run from repo root:**

```bash
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900
```

**Optional extra vars** (match the script’s env vars):

| Variable | Default | Description |
|----------|---------|-------------|
| `template_name` | `ubuntu-cloud` | Template name in Proxmox. |
| `storage` | `local-lvm` | Proxmox storage ID. |
| `ubuntu_release` | `jammy` | e.g. `jammy` (22.04) or `noble` (24.04). |
| `template_disk_resize` | *(empty)* | e.g. `+20G`. |
| `memory` | `1024` | MB. |
| `cores` | `1` | vCPU count. |
| `ipconfig0` | `ip=dhcp` | Cloud-init network. |
| `ciuser` | *(empty)* | Optional default cloud-init user. |
| `cipassword` | *(empty)* | Optional default cloud-init password. |
| `create_ubuntu_template_ssh_key_path` | *(empty)* | Path on Proxmox host to SSH public key file. |
| `template_work_dir` | `/var/lib/vz/template/iso` | Directory for downloaded image. |

**Examples:**

```bash
# Ubuntu 24.04, larger disk
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=901 -e ubuntu_release=noble -e template_disk_resize=+20G

# Custom name and storage
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=901 -e template_name=ubuntu-jammy-ci -e storage=ssd-lvm
```

Ensure the VMID is free on the Proxmox node (e.g. `qm list`) and that `template_name` / VMID match your Terraform config.
