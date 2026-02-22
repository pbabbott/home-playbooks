# Terraform codebase overview

How the `terraform/` directory is structured and how the pieces fit together.

---

## Directory layout

```
terraform/
├── provider.tf              # Proxmox provider config (API URL, token)
├── versions.tf              # Terraform + provider version constraints
├── variables.tf             # Root variables (API, node, template, storage, nonprod_vms)
├── main.tf                  # VM definitions (non-prod fleet via module)
├── outputs.tf               # Outputs (VM IDs, names, IPs)
├── terraform.tfvars.example # Example tfvars — copy to terraform.tfvars
├── .gitignore               # Ignores .terraform/, state, *.tfvars
├── modules/
│   └── vm/                  # Reusable VM module (clone + cloud-init)
│       ├── main.tf          # proxmox_vm_qemu resource
│       ├── variables.tf     # Module inputs
│       └── outputs.tf       # vm_id, vm_name, ip_address
├── scripts/
│   └── create-ubuntu-template.sh  # Build cloud-init template (VMID required)
└── docs/
    ├── terraform-overview.md     # This file
    ├── getting-started.md        # Setup and common commands
    └── template-script-parity.md # Template script vs old notes
```

---

## Root-level files

### Provider and runtime

- **provider.tf** — Configures the [Telmate Proxmox](https://registry.terraform.io/providers/Telmate/proxmox/latest) provider. Uses variables for API URL and token (no secrets in code). `pm_tls_insecure = true` is set for typical self-signed Proxmox certs.
- **versions.tf** — Pins Terraform `>= 1.0` and the Proxmox provider `~> 3.0`. Run `terraform init` after changing provider requirements.

### Variables and values

- **variables.tf** — Declares all root inputs:
  - **Proxmox**: `proxmox_api_url`, `proxmox_api_token_id`, `proxmox_api_token_secret`, `proxmox_node`
  - **Template and storage**: `template_name`, `storage`, `storage_ssd`, `bridge`
  - **SSH**: `ssh_public_key_path`
  - **Fleet**: `nonprod_vms` — map of VM name → VMID (default: four non-prod k8s VMs in the 300 range)
- **terraform.tfvars.example** — Example values for the above. Copy to `terraform.tfvars` and fill in real values; `terraform.tfvars` is gitignored so secrets stay local.

### Resources and outputs

- **main.tf** — Defines the VMs. Currently a single `module "nonprod_vm"` with `for_each = var.nonprod_vms`, so one VM is created per entry in the map. Each instance gets the same template, node, storage, and SSH key; only `vmid` and `name` vary per VM. A commented block shows how to add VMs on SSD (`var.storage_ssd`) if needed.
- **outputs.tf** — Exposes `nonprod_vm_ids`, `nonprod_vm_names`, and `nonprod_vm_ip_addresses` as maps keyed by VM name. Use these for Ansible inventory or scripts (e.g. `terraform output -json nonprod_vm_ip_addresses`).

---

## The `vm` module

**Path:** `modules/vm/`

A single reusable module that creates one Proxmox VM by cloning a cloud-init template.

### What it does

- Clones the given template (`clone` + `full_clone`).
- Sets CPU, memory, and a single SCSI disk (size and storage configurable).
- Adds one virtio NIC on the given bridge.
- Configures cloud-init: SSH key, `ipconfig0` (e.g. DHCP), and uses the same storage for the cloud-init CDROM as for the disk unless overridden.
- Enables the QEMU agent so Proxmox can report the VM’s IP when qemu-guest-agent is installed in the guest.

### Inputs (variables.tf)

| Variable | Required | Description |
|----------|----------|-------------|
| `name` | yes | VM name (hostname in Proxmox). |
| `vmid` | no (default 0) | Proxmox VM ID; 0 = auto-assign. Prefer explicit IDs (200/300/500 ranges). |
| `target_node` | yes | Proxmox node name. |
| `template_name` | yes | Name of the cloud-init template to clone. |
| `cores`, `memory`, `disk_size` | no | CPU, RAM (MB), disk (e.g. `20G`). |
| `storage` | yes | Storage for the disk (and cloud-init CDROM unless set). |
| `bridge` | no | Network bridge (default `vmbr0`). |
| `ssh_public_key` | yes | SSH public key content for cloud-init. |
| `ip_config` | no | Cloud-init network (default `ip=dhcp`). |
| `cloudinit_cdrom_storage` | no | Override storage for cloud-init CDROM. |

### Outputs (outputs.tf)

| Output | Description |
|--------|-------------|
| `vm_id` | Proxmox VM ID. |
| `vm_name` | VM name. |
| `ip_address` | Primary IPv4 from qemu-guest-agent, or `null` if not available. |

---

## Scripts

- **scripts/create-ubuntu-template.sh** — Builds an Ubuntu cloud-init template on the Proxmox host (or a machine with Proxmox CLI). **VMID is required** as first argument (e.g. `./create-ubuntu-template.sh 900`) to avoid overwriting existing VMs. Supports env vars for release (jammy/noble), disk resize, and optional cloud-init defaults. See [template-script-parity.md](template-script-parity.md) for details and parity with older notes.

---

## How it fits together

1. **Template** — Create a cloud-init template (e.g. VMID 900) using the script or by hand. Set `template_name` in `terraform.tfvars` to match.
2. **Root variables** — Values in `terraform.tfvars` (and optionally env vars) feed into `variables.tf`. Provider config in `provider.tf` uses the API variables.
3. **Fleet definition** — `var.nonprod_vms` is a map of VM name → VMID. `main.tf` loops over this map with `for_each` and instantiates the `vm` module once per entry.
4. **Module** — Each module instance gets one VMID and one name from the map, plus shared values (node, template, storage, SSH key, etc.) from root variables. The module creates a single `proxmox_vm_qemu` resource (clone + cloud-init).
5. **Outputs** — Root `outputs.tf` aggregates module outputs into maps keyed by VM name, so you get one set of outputs for the whole non-prod fleet.

To add or remove VMs, change the `nonprod_vms` map (in code or via tfvars). To add a different fleet (e.g. dev workstations in the 500 range), add another module block and a similar map variable, and expose their outputs in `outputs.tf`.
