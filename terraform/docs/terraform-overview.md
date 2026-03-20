# Terraform codebase overview

How the `terraform/` directory is structured and how the pieces fit together.

---

## Directory layout

```text
terraform/
├── provider.tf              # Proxmox provider config (API URL, token)
├── versions.tf              # Terraform + provider version constraints
├── variables.tf             # Root variables (API, VM fleet, template name)
├── main.tf                  # VM definitions (non-prod fleet via module)
├── outputs.tf               # Outputs (VM IDs, names, IPs)
├── terraform.tfvars.example # Example tfvars - copy to terraform.tfvars
├── .gitignore               # Ignores .terraform/, state, *.tfvars
└── modules/
    └── vm/                  # Reusable VM module (clone + cloud-init)
        ├── main.tf          # proxmox_virtual_environment_vm resource (BPG provider)
        ├── variables.tf     # Module inputs
        └── outputs.tf       # vm_id, vm_name
```

---

## Root-level files

### Provider and runtime

- **provider.tf** - Configures the [BPG Proxmox](https://github.com/bpg/terraform-provider-proxmox) provider ([Terraform Registry](https://registry.terraform.io/providers/bpg/proxmox/latest)). Uses variables for API URL and token (no secrets in code). Endpoint is normalized from `proxmox_api_url`; `insecure = true` is set for common self-signed Proxmox certs.
- **versions.tf** - Pins Terraform `>= 1.4` and the Proxmox provider `~> 0.58`.

### Variables and values

- **variables.tf** - Declares all root inputs:
  - **Proxmox**: `proxmox_api_url`, `proxmox_api_token_id`, `proxmox_api_token_secret`, `proxmox_node`
  - **Template and cloud-init**: `template_name` (template created by playbooks/proxmox/create-ubuntu-template.yml), `storage` (pool for cloud-init snippets on clones), `bridge`
  - **SSH**: `ssh_public_key_path`
  - **Fleet**: `nonprod_vms` - map of VM name -> VMID
- **terraform.tfvars.example** - Example values. Copy to `terraform.tfvars` and fill in real local values; `terraform.tfvars` is gitignored.

### Resources and outputs

- **main.tf** - Defines VMs using `module "nonprod_vm"` (and optionally `module "prod_vm"`) with `for_each`, so one module instance is created per map entry. A data source resolves `template_name` to a template VM ID for the BPG provider clone.
  - **Disks** are not declared in Terraform: full clones inherit the template’s disk layout. The module uses `lifecycle.ignore_changes` for `disk` so applies do not fight Proxmox over disks.
  - The Ubuntu cloud-init template is **not** managed by Terraform; it must be created first via `playbooks/proxmox/create-ubuntu-template.yml`.
- **outputs.tf** - Exposes `nonprod_vm_ids`, `nonprod_vm_names`, and the analogous prod outputs as maps keyed by VM name. Static IPs are inputs (`nonprod_static_ips`, `prod_static_ips`), not outputs.

---

## The `vm` module

**Path:** `modules/vm/`

Reusable module that creates one Proxmox VM by cloning a cloud-init template.

### What it does

- Clones the given template via BPG `clone` block (`full = true`).
- Sets CPU and memory; **does not** declare VM disks (they come from the template; `lifecycle.ignore_changes` includes `disk`).
- Adds one virtio NIC on the selected bridge.
- Configures cloud-init (initialization block: SSH keys, ip_config, optional `cloudinit_cdrom_storage`).
- Enables QEMU guest agent and serial device (for Debian 12/Ubuntu compatibility).

### Inputs (modules/vm/variables.tf)

| Variable | Required | Description |
|----------|----------|-------------|
| `name` | yes | VM name (hostname in Proxmox). |
| `vmid` | no (default 0) | Proxmox VM ID; 0 = auto-assign. Prefer explicit IDs (200/300/500 ranges). |
| `target_node` | yes | Proxmox node name. |
| `template_id` | yes | Proxmox VM ID of the template to clone (resolved from `template_name` in root). |
| `cores`, `memory` | no | CPU and RAM (MB). |
| `storage` | yes | Proxmox pool for the cloud-init snippet drive (not for template VM disks). |
| `bridge` | no | Network bridge (default `vmbr0`). |
| `ssh_public_key` | yes | SSH public key content for cloud-init. |
| `ip_config` | no | Cloud-init network (default `ip=dhcp`). |
| `cloudinit_cdrom_storage` | no | Override storage pool for cloud-init CDROM (default: `storage`). |

### Outputs (modules/vm/outputs.tf)

| Output | Description |
|--------|-------------|
| `vm_id` | Proxmox VM ID. |
| `vm_name` | VM name. |

---

## Templates

The Ubuntu cloud-init template (900-range VMID by convention) is **not** managed by Terraform. Create or refresh it with the Ansible playbook before running Terraform:

```bash
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml
```

Set `template_name` in `terraform.tfvars` to match the template name from that playbook (e.g. `tf-template-ubuntu-noble`).

---

## How it fits together

1. **Template (prerequisite)** - Create the Ubuntu cloud-init template on Proxmox using `playbooks/proxmox/create-ubuntu-template.yml`.
2. **Root variables** - Values from `terraform.tfvars` feed `variables.tf`; provider config in `provider.tf` uses API variables.
3. **Fleet definition** - `var.nonprod_vms` maps VM name -> VMID. `main.tf` loops this map with `for_each`.
4. **Module** - Each module instance creates one cloned VM with shared settings (node, cloud-init `storage`, bridge, SSH key) plus per-VM `name` and `vmid`.
5. **Outputs** - Root outputs expose VM IDs and names keyed by VM name. Use `nonprod_static_ips` / `prod_static_ips` for Ansible `ansible_host` values.

To add or remove non-prod VMs, change entries in `nonprod_vms` (in code or tfvars). To manage another fleet, add another module block and matching variable/output pattern.

---

## Migrating from Telmate provider

This codebase uses the [BPG Proxmox provider](https://github.com/bpg/terraform-provider-proxmox). If you previously used the Telmate provider, the resource type changed from `proxmox_vm_qemu` to `proxmox_virtual_environment_vm`. Options:

- **New setup** – Run `terraform init -upgrade` and then `terraform plan` / `apply` as usual.
- **Existing VMs in state** – Either remove the old resources from state and import them under the new type (see [provider docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm)), or plan a destroy/recreate (back up state first).
