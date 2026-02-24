# Creating an Ubuntu cloud-init template for Proxmox (Terraform)

Template creation now lives in this Terraform stack. It is primarily managed by the Proxmox provider resource:

- `ubuntu-template.tf` (`proxmox_vm_qemu.ubuntu_template`)

Terraform-native VM settings (CPU, memory, network, cloud-init, boot order, serial console, cloud-init drive, SSH keys) are configured in `proxmox_vm_qemu`.

Small inline `local-exec` steps are still used only for provider gaps:

- Download the Ubuntu cloud image to the Proxmox host if missing.
- Import image into storage (`qm importdisk`) and attach as `scsi0`.
- Optional `qm resize` for `scsi0`.
- `qm template` conversion after VM creation.

---

## 1) Configure template variables

Set these values in `terraform.tfvars` (or keep the defaults if they match your environment):

```hcl
create_ubuntu_template          = true
ubuntu_template_name_prefix     = "tf-template-ubuntu"
ubuntu_template_primary_release = "noble"
ubuntu_template_vmids = {
  noble = 901
  # jammy = 902
}
ubuntu_template_storage         = "local-lvm"
ubuntu_template_disk_resize     = "+32G"
ubuntu_template_memory          = 6144
ubuntu_template_cores           = 4
ssh_public_key_path             = "~/.ssh/id_ed25519.pub"
# ubuntu_template_ssh_public_key_path_on_proxmox = "/root/.ssh/authorized_keys.pub"
```

With this model, adding a second template is just one map entry (for example `jammy = 902`).
Template names are generated automatically as `<ubuntu_template_name_prefix>-<release>` (for example `tf-template-ubuntu-noble`).

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
- Template VMIDs are driven by `ubuntu_template_vmids` (release -> vmid).
- `ubuntu_template_primary_release` controls which built template cloned VMs use by default.
- The same `ssh_public_key_path` variable is used for both template creation and cloned VMs.
- If `ssh_public_key_path` does not exist locally, you can set `ubuntu_template_ssh_public_key_path_on_proxmox` to a key file that already exists on the Proxmox host.
- VM clone modules use the generated primary template name (`<prefix>-<primary_release>`) when template creation is enabled.
