# Terraform codebase overview

How the `terraform/` directory is structured and how the pieces fit together.

---

## Directory layout

```text
terraform/
├── provider.tf              # Proxmox provider config (API URL, token)
├── versions.tf              # Terraform + provider version constraints
├── variables.tf             # Root variables (API, template build, VM fleet)
├── ubuntu-template.tf       # Ubuntu template build (provider + minimal SSH helpers)
├── main.tf                  # VM definitions (non-prod fleet via module)
├── outputs.tf               # Outputs (VM IDs, names, IPs)
├── terraform.tfvars.example # Example tfvars - copy to terraform.tfvars
├── .gitignore               # Ignores .terraform/, state, *.tfvars
└── modules/
    └── vm/                  # Reusable VM module (clone + cloud-init)
        ├── main.tf          # proxmox_vm_qemu resource
        ├── variables.tf     # Module inputs
        └── outputs.tf       # vm_id, vm_name, ip_address
```

---

## Root-level files

### Provider and runtime

- **provider.tf** - Configures the [Telmate Proxmox](https://registry.terraform.io/providers/Telmate/proxmox/latest) provider. Uses variables for API URL and token (no secrets in code). `pm_tls_insecure = true` is set for common self-signed Proxmox certs.
- **versions.tf** - Pins Terraform `>= 1.4` and the Proxmox provider `~> 3.0`.

### Variables and values

- **variables.tf** - Declares all root inputs:
  - **Proxmox**: `proxmox_api_url`, `proxmox_api_token_id`, `proxmox_api_token_secret`, `proxmox_node`
  - **Template build**: `create_ubuntu_template`, `ubuntu_template_name_prefix`, `ubuntu_template_primary_release`, `ubuntu_template_vmids`, plus template build settings
  - **Template/VM storage and clone source**: `template_name`, `storage`, `storage_ssd`, `bridge`
  - **Worker SSD data disk controls**: `enable_nonprod_worker_ssd_data_disk`, `nonprod_worker_ssd_data_disk_size`
  - **SSH**: `ssh_public_key_path`
  - **Fleet**: `nonprod_vms` - map of VM name -> VMID
- **terraform.tfvars.example** - Example values. Copy to `terraform.tfvars` and fill in real local values; `terraform.tfvars` is gitignored.

### Resources and outputs

- **main.tf** - Defines VMs using `module "nonprod_vm"` with `for_each = var.nonprod_vms`, so one module instance is created per map entry.
  - Non-prod worker VMs (name contains `-worker-`) are configured to attach an additional SSD-backed data disk when `enable_nonprod_worker_ssd_data_disk = true`.
- **outputs.tf** - Exposes `nonprod_vm_ids`, `nonprod_vm_names`, and `nonprod_vm_ip_addresses` as maps keyed by VM name.
- **ubuntu-template.tf** - Defines two resources used when `create_ubuntu_template = true`:
  - `terraform_data.ubuntu_template_image` ensures each cloud image exists on the Proxmox host.
  - `proxmox_vm_qemu.ubuntu_template` creates template VMs using `for_each` over `ubuntu_template_vmids` (release -> vmid), then runs small `local-exec` steps for `qm importdisk`, `qm set --scsi0`, optional `qm resize`, and `qm template`.

---

## The `vm` module

**Path:** `modules/vm/`

Reusable module that creates one Proxmox VM by cloning a cloud-init template.

### What it does

- Clones the given template (`clone` + `full_clone`).
- Sets CPU, memory, and one SCSI disk (size and storage configurable).
- Optionally attaches a second SCSI disk (`scsi1`) for SSD-backed data storage.
- Adds one virtio NIC on the selected bridge.
- Configures cloud-init (`sshkeys`, `ipconfig0`, and optional `cloudinit_cdrom_storage` override).
- Enables QEMU guest agent reporting (`agent = 1`) for IP discovery when available in the guest.

### Inputs (modules/vm/variables.tf)

| Variable | Required | Description |
|----------|----------|-------------|
| `name` | yes | VM name (hostname in Proxmox). |
| `vmid` | no (default 0) | Proxmox VM ID; 0 = auto-assign. Prefer explicit IDs (200/300/500 ranges). |
| `target_node` | yes | Proxmox node name. |
| `template_name` | yes | Name of the cloud-init template to clone. |
| `cores`, `memory`, `disk_size` | no | CPU, RAM (MB), disk (for example `20G`). |
| `storage` | yes | Storage for the main disk. |
| `enable_ssd_data_disk` | no | If `true`, adds a second data disk at `scsi1`. |
| `ssd_data_disk_storage`, `ssd_data_disk_size` | no | Storage target and size for the optional SSD data disk. |
| `bridge` | no | Network bridge (default `vmbr0`). |
| `ssh_public_key` | yes | SSH public key content for cloud-init. |
| `ip_config` | no | Cloud-init network (default `ip=dhcp`). |
| `cloudinit_cdrom_storage` | no | Override storage for cloud-init CDROM. |

### Outputs (modules/vm/outputs.tf)

| Output | Description |
|--------|-------------|
| `vm_id` | Proxmox VM ID. |
| `vm_name` | VM name. |
| `ip_address` | Primary IPv4 from qemu-guest-agent, or `null` if unavailable. |

---

## Templates

Ubuntu templates (900-range VMIDs by convention) are managed through:

- **`terraform_data.ubuntu_template_image`** — Ensures each Ubuntu cloud image is present on the Proxmox host (download/copy into the work dir); runs first so the template VMs can import the disk.
- **`proxmox_vm_qemu.ubuntu_template`** — Creates the actual template VMs (one per release in `ubuntu_template_vmids`), runs `qm importdisk` / `qm set` / `qm template`, and is the clone source used by the VM module.

Set `create_ubuntu_template = true` to enable template creation and configure template map variables in `terraform.tfvars`. For details, see [create-ubuntu-template.md](create-ubuntu-template.md).

---

## How it fits together

1. **Template (optional)** - Build one or many Ubuntu cloud-init templates from `ubuntu_template_vmids`.
2. **Root variables** - Values from `terraform.tfvars` feed `variables.tf`; provider config in `provider.tf` uses API variables.
3. **Fleet definition** - `var.nonprod_vms` maps VM name -> VMID. `main.tf` loops this map with `for_each`.
4. **Module** - Each module instance creates one cloned VM with shared settings (node, storage, bridge, SSH key) plus per-VM `name` and `vmid`. Worker nodes can also receive an additional SSD-backed data disk via module inputs.
5. **Outputs** - Root outputs aggregate module outputs into maps keyed by VM name for automation use.

To add or remove non-prod VMs, change entries in `nonprod_vms` (in code or tfvars). To manage another fleet, add another module block and matching variable/output pattern.
