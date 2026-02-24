# Creating an Ubuntu cloud-init template for Proxmox (Terraform)

Template creation now lives in this Terraform stack. It is primarily managed by the Proxmox provider resource:

- `ubuntu-template.tf` (`proxmox_vm_qemu.ubuntu_template`)

Terraform-native VM settings (CPU, memory, network, cloud-init, boot order, serial console, cloud-init drive, SSH keys) are configured in `proxmox_vm_qemu`.

Small inline `local-exec` steps are still used only for provider gaps:

- Download the Ubuntu cloud image to the Proxmox host if missing.
- Optional `qm resize` for `scsi0`.
- `qm template` conversion after VM creation.

---

## 1) Configure template variables

Set these values in `terraform.tfvars` (or keep the defaults if they match your environment):

```hcl
create_ubuntu_template         = true
ubuntu_template_vmid           = 901
ubuntu_template_name           = "tf-template-ubuntu-noble"
ubuntu_template_storage        = "local-lvm"
ubuntu_template_ubuntu_release = "noble"
ubuntu_template_disk_resize    = "+32G"
ubuntu_template_memory         = 6144
ubuntu_template_cores          = 4
ssh_public_key_path            = "~/.ssh/id_ed25519.pub"
```

Defaults are based on the latest successful command history entry in `playbooks/proxmox/README.md` dated `02/22/2026`.

---

## 2) Build or refresh the template

From `terraform/`:

```bash
terraform apply -target=proxmox_vm_qemu.ubuntu_template
```

Or run a normal apply (`terraform apply`) if you also want Terraform to manage VM clones in the same run.

---

## Notes

- The template build is **optional**; it only runs when `create_ubuntu_template = true`.
- If core template settings change, Terraform recreates `proxmox_vm_qemu.ubuntu_template` (via `force_recreate_on_change_of`) so the template remains consistent.
- The template is recreated for the configured `ubuntu_template_vmid` when those core inputs change.
- The same `ssh_public_key_path` variable is used for both template creation and cloned VMs.
- VM clone modules use `ubuntu_template_name` when template creation is enabled, so the clone source stays in sync.
