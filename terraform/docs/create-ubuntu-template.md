# Creating an Ubuntu cloud-init template for Proxmox

This guide explains how to create a Proxmox VM template from an Ubuntu cloud image. You can use either:

- **Ansible** (recommended): [playbooks/proxmox/create-ubuntu-template.yml](../../playbooks/proxmox/create-ubuntu-template.yml) — run from your machine against the Proxmox host (inventory group `proxmox_hosts`). See [playbooks/proxmox/README.md](../../playbooks/proxmox/README.md).
- **Shell script:** [../scripts/create-ubuntu-template.sh](../scripts/create-ubuntu-template.sh) — run on the Proxmox host or from a machine with API/shell access.

The resulting template is used by Terraform to clone VMs (see [getting-started.md](getting-started.md) and [terraform-overview.md](terraform-overview.md)).

---

## What the script does

The script performs these steps in order:

1. **Download** the Ubuntu cloud image for the chosen release (if not already present in the current directory).
2. **Create** a new Proxmox VM with the given VMID, name, memory, and cores.
3. **Import** the cloud image as a disk into the configured Proxmox storage.
4. **Attach** the disk as SCSI 0 (virtio-scsi) so the VM can boot from it.
5. **Optionally resize** the template disk (e.g. `+20G`) so clones have more space by default.
6. **Add** a cloud-init drive (IDE2) so user, SSH keys, and network config can be injected when cloning.
7. **Set** boot order (scsi0), serial console, and VGA to serial for Proxmox console access.
8. **Optionally set** cloud-init defaults on the template (user, password, SSH key, IP config); Terraform overrides these per clone.
9. **Convert** the VM to a template so it cannot be started and is only used for cloning.

The template is minimal and cloud-init–ready; Terraform injects SSH keys and network (e.g. static IP) per clone. For conventions (e.g. VMID 900 range), see [preferences-and-conventions.md](preferences-and-conventions.md).

---

## What is created in Proxmox

After a successful run you will have:

| Resource | Description |
|----------|-------------|
| **Template** | A non-startable VM (VMID you chose, e.g. 900) named e.g. `ubuntu-cloud`. |
| **Disk** | One primary disk (SCSI 0) from the Ubuntu cloud image, optionally resized. |
| **Cloud-init drive** | IDE2 cloud-init drive on the template; each clone gets its own cloud-init data from Terraform. |

Terraform uses this template to **clone** VMs; it does not start or modify the template itself. Optional: install `qemu-guest-agent` in each clone after first boot (or via Ansible) for better IP reporting in Proxmox.

---

## Requirements

- **VMID** must be set explicitly (e.g. 900 for templates) so the script does not overwrite an existing VM. Pass it as the first argument or via the `VMID` environment variable.
- **Storage** must exist on the Proxmox host (default: `local-lvm`).
- **Network** bridge (default: `vmbr0`) must exist for the VM’s net0.
- If you set `SSH_PUBLIC_KEY_PATH`, the file must exist on the machine running the script (typically the Proxmox host).

---

## Configuration (environment variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `VMID` | *(required)* | Proxmox VM/template ID (e.g. 900). Pass as first argument or env. |
| `TEMPLATE_NAME` | `ubuntu-cloud` | Name of the template in Proxmox. |
| `STORAGE` | `local-lvm` | Proxmox storage ID for the disk and cloud-init drive. |
| `UBUNTU_RELEASE` | `jammy` | Ubuntu release: `jammy` (22.04) or `noble` (24.04). |
| `TEMPLATE_DISK_RESIZE` | *(empty)* | Optional resize, e.g. `+20G`. |
| `MEMORY` | `1024` | Template VM memory (MB). Clones get their own via Terraform. |
| `CORES` | `1` | Template VM cores. |
| `IPCONFIG0` | `ip=dhcp` | Cloud-init network config for the template. |
| `CIUSER` | *(empty)* | Optional default cloud-init user. |
| `CIPASSWORD` | *(empty)* | Optional default cloud-init password. |
| `SSH_PUBLIC_KEY_PATH` | *(empty)* | Optional path to SSH public key file on the host. |

---

## How to run

### Option A: Ansible (from repo root)

Targets the Proxmox host via inventory group `proxmox_hosts` (e.g. chimaera). No need to log in to the host first.

```bash
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml -e vmid=900
```

See [playbooks/proxmox/README.md](../../playbooks/proxmox/README.md) for optional variables and examples.

### Option B: Shell script

Run from the **terraform** directory (or ensure the script path and any local image path are correct). The script must be executed in a context where `qm` (Proxmox CLI) is available—typically on the Proxmox host.

### Basic: template with VMID 900 (Ubuntu 22.04 Jammy)

```bash
cd terraform
./scripts/create-ubuntu-template.sh 900
```

This creates a template named `ubuntu-cloud` (VMID 900), using `local-lvm` and the default Jammy cloud image.

### Ubuntu 24.04 (Noble) with a larger disk

```bash
UBUNTU_RELEASE=noble TEMPLATE_DISK_RESIZE=+20G ./scripts/create-ubuntu-template.sh 900
```

### Custom template name and storage

```bash
TEMPLATE_NAME=ubuntu-jammy-ci STORAGE=ssd-lvm ./scripts/create-ubuntu-template.sh 900
```

### With optional cloud-init defaults (e.g. for manual clones in the UI)

```bash
CIUSER=admin \
CIPASSWORD='your-secure-password' \
SSH_PUBLIC_KEY_PATH=/root/.ssh/authorized_keys.pub \
./scripts/create-ubuntu-template.sh 900
```

### All options in one go

```bash
VMID=901 \
TEMPLATE_NAME=ubuntu-noble \
STORAGE=local-lvm \
UBUNTU_RELEASE=noble \
TEMPLATE_DISK_RESIZE=+32G \
MEMORY=2048 \
CORES=2 \
./scripts/create-ubuntu-template.sh
```

Here `VMID` is set in the environment, so the script can be run as `./scripts/create-ubuntu-template.sh` with no arguments.

---

## Ensuring correctness

1. **Avoid overwriting VMs**  
   Always pass an explicit VMID (e.g. 900). Check that the VMID is free in Proxmox before running:
   ```bash
   qm list
   ```

2. **Re-download the image**  
   If you need a fresh image, delete the existing one in the current directory and run the script again:
   ```bash
   rm -f jammy-server-cloudimg-amd64.img noble-server-cloudimg-amd64.img
   ./scripts/create-ubuntu-template.sh 900
   ```

3. **Match Terraform and conventions**  
   Use the same template name and VMID in `terraform.tfvars` (and [preferences-and-conventions.md](preferences-and-conventions.md)). For example, if you create template `ubuntu-cloud` with VMID 900, set `template_name = "ubuntu-cloud"` and ensure no other VM uses 900.

4. **Run from the Proxmox host**  
   For the least friction, run the script on the Proxmox host so `qm` and storage are local. If you run remotely, ensure the image is downloaded where the script runs and that `qm` is available (e.g. via SSH).

When the script finishes, it prints that the template is ready for Terraform clones. You can then use [getting-started.md](getting-started.md) to configure Terraform and run `terraform plan` / `terraform apply`.
