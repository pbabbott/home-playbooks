# Proxmox playbooks

Playbooks that run against the Proxmox host(s) (inventory group `proxmox_hosts`).

---

## create-ubuntu-template.yml

Creates a Proxmox cloud-init template from an Ubuntu cloud image. The resulting template is used by **Terraform** to clone VMs (see [terraform/docs/getting-started.md](../../terraform/docs/getting-started.md) and [terraform/docs/terraform-overview.md](../../terraform/docs/terraform-overview.md)).

### What the playbook does

The playbook performs these steps in order:

1. **Validate** that `vmid` is set and is a positive integer (fails early otherwise).
2. **Create** the work directory for the cloud image (default `/var/lib/vz/template/cloud`).
3. **Download** the Ubuntu cloud image for the chosen release (if not already present on the Proxmox host).
4. **Create** a new Proxmox VM with the given VMID, name, memory, and cores.
5. **Import** the cloud image as a disk into the configured Proxmox storage.
6. **Attach** the disk as SCSI 0 (virtio-scsi) so the VM can boot from it.
7. **Optionally resize** the template disk (e.g. `+20G`) when `template_disk_resize` is set.
8. **Add** a cloud-init drive (IDE2) so user, SSH keys, and network config can be injected when cloning.
9. **Set** boot order (scsi0), serial console, and VGA to serial for Proxmox console access.
10. **Set** cloud-init ipconfig0 (default `ip=dhcp`), and optionally ciuser, cipassword, and SSH key (from workstation path or Proxmox path).
11. **Convert** the VM to a template so it cannot be started and is only used for cloning.

The template is minimal and cloud-init–ready; Terraform injects SSH keys and network (e.g. static IP) per clone. For VMID conventions (e.g. 900 for templates), see [terraform/docs/preferences-and-conventions.md](../../terraform/docs/preferences-and-conventions.md).

### What is created in Proxmox

After a successful run you will have:

| Resource | Description |
|----------|-------------|
| **Template** | A non-startable VM (VMID you chose, e.g. 900) named e.g. `ubuntu-cloud`. |
| **Disk** | One primary disk (SCSI 0) from the Ubuntu cloud image, optionally resized. |
| **Cloud-init drive** | IDE2 cloud-init drive on the template; each clone gets its own cloud-init data from Terraform. |

Terraform uses this template to **clone** VMs; it does not start or modify the template itself. Optional: install `qemu-guest-agent` in each clone after first boot (or via Ansible) for better IP reporting in Proxmox.

**By design, the playbook does not:**

- **Set `onboot 1` on the template** — Templates are not started. If you want cloned VMs to start on host boot, configure that on the clone (e.g. via Terraform or Proxmox UI).
- **Boot the template or install qemu-guest-agent in it** — Cloud-init runs only at first boot, so the template is never started. Install qemu-guest-agent in each clone after first boot (or via Ansible) for better IP reporting in Proxmox.

### Requirements

- **VMID** must be set explicitly (e.g. 900 for templates) and must be a positive integer. Pass it with `-e vmid=900`. The playbook will fail if vmid is missing or invalid.
- **Storage** must exist on the Proxmox host (default: `local-lvm`).
- **Network** bridge (default: `vmbr0`) must exist for the VM’s net0.
- For SSH keys: use `create_ubuntu_template_ssh_key_local_path` (e.g. `~/.ssh/id_ed25519.pub`) to use a key from your workstation; the playbook copies it to the Proxmox host and into the template. Alternatively, use `create_ubuntu_template_ssh_key_path` with a path to a key file that already exists on the Proxmox host.

**Where to put cloud images:** Use `/var/lib/vz/template/cloud` on the Proxmox host for all cloud-init images (Ubuntu, Debian, etc.). The playbook downloads there by default. Keep installer ISOs in `/var/lib/vz/template/iso` so the two are separate.

### Configuration (extra vars)

| Variable | Default | Description |
|----------|---------|-------------|
| `vmid` | *(required)* | Proxmox VM/template ID (e.g. 900). Pass with `-e vmid=900`. |
| `template_name` | `ubuntu-cloud` | Name of the template in Proxmox. |
| `storage` | `local-lvm` | Proxmox storage ID for the disk and cloud-init drive. |
| `ubuntu_release` | `jammy` | Ubuntu release: `jammy` (22.04) or `noble` (24.04). |
| `template_disk_resize` | *(empty)* | Optional resize, e.g. `+20G`. |
| `memory` | `1024` | Template VM memory (MB). Clones get their own via Terraform. |
| `cores` | `1` | Template VM cores. |
| `ipconfig0` | `ip=dhcp` | Cloud-init network config for the template. |
| `ciuser` | *(empty)* | Optional default cloud-init user. |
| `cipassword` | From vault (`inventoryPasswords.kubernetes_node`) when using `-e @./vault.yml` | Default cloud-init password; override with `-e cipassword=...`. |
| `create_ubuntu_template_ssh_key_path` | *(empty)* | Path on the Proxmox host to an SSH public key file (used only when `create_ubuntu_template_ssh_key_local_path` is not set). |
| `create_ubuntu_template_ssh_key_local_path` | *(empty)* | Path on your workstation to an SSH public key (e.g. `~/.ssh/id_ed25519.pub`). The key is read locally, copied to the Proxmox host, and injected into the template. |
| `template_work_dir` | `/var/lib/vz/template/cloud` | Directory on the Proxmox host for the downloaded image and temporary SSH key. |

### How to run

Run from **repo root**. The playbook targets the Proxmox host via inventory group `proxmox_hosts`; you do not need to log in to the host first.

**Basic: template with VMID 900 (Ubuntu 22.04 Jammy)**

```bash
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900
```

This creates a template named `ubuntu-cloud` (VMID 900), using `local-lvm` and the default Jammy cloud image.

**Ubuntu 24.04 (Noble) with a larger disk**

```bash
ansible-playbook -e @./vault.yml -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900 -e ubuntu_release=noble -e template_disk_resize=+20G
```

**Custom template name and storage**

```bash
ansible-playbook -e @./vault.yml -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900 -e template_name=ubuntu-jammy-ci -e storage=ssd-lvm
```

**With optional cloud-init defaults (e.g. for manual clones in the UI)**

Using an SSH key from your workstation (recommended; `~` is expanded to your home directory):

```bash
ansible-playbook -e @./vault.yml -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900 \
  -e ciuser=admin -e cipassword='your-secure-password' \
  -e create_ubuntu_template_ssh_key_local_path=~/.ssh/id_ed25519.pub
```

Or using a key that already exists on the Proxmox host:

```bash
ansible-playbook -e @./vault.yml -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900 \
  -e ciuser=admin -e cipassword='your-secure-password' \
  -e create_ubuntu_template_ssh_key_path=/root/.ssh/authorized_keys.pub
```

**All options in one go**

```sh
ansible-playbook -i inventory.yml -e @./vault.yml \
  -e vmid=901 \
  -e template_name=ubuntu-noble \
  -e storage=local-lvm \
  -e ubuntu_release=noble \
  -e template_disk_resize=+32G \
  -e memory=2048 \
  -e cores=2 \
  playbooks/proxmox/create-ubuntu-template.yml
```

### Ensuring correctness

1. **Avoid overwriting VMs**  
   Always pass an explicit VMID (e.g. 900). Check that the VMID is free on the Proxmox host before running (e.g. `qm list` on the host, or via Ansible).

2. **Re-download the image**  
   If you need a fresh image, remove the existing file on the Proxmox host from `template_work_dir` (default `/var/lib/vz/template/cloud`), then run the playbook again.

3. **Match Terraform and conventions**  
   Use the same template name and VMID in `terraform/terraform.tfvars` and [terraform/docs/preferences-and-conventions.md](../../terraform/docs/preferences-and-conventions.md). For example, if you create template `ubuntu-cloud` with VMID 900, set `template_name = "ubuntu-cloud"` in tfvars and ensure no other VM uses 900.


When the playbook finishes, the template is ready for Terraform clones. Use [terraform/docs/getting-started.md](../../terraform/docs/getting-started.md) to configure Terraform and run `terraform plan` / `terraform apply`.

# Command History

## 02/22/2026
This command worked for me to make template 901

```sh
ansible-playbook -i inventory.yml -e @./vault.yml \
  -e create_ubuntu_template_ssh_key_local_path=~/.ssh/id_ed25519.pub \
  -e vmid=901 \
  -e template_name=ubuntu-noble-cloud \
  -e storage=local-lvm \
  -e ubuntu_release=noble \
  -e template_disk_resize=+32G \
  -e memory=6144 \
  -e cores=4 \
  playbooks/proxmox/create-ubuntu-template.yml
```