# Creating an Ubuntu cloud-init template for Proxmox (Terraform)

Template creation now lives in this Terraform stack. Terraform runs the `qm` workflow over SSH via:

- `template.tf` (`terraform_data.ubuntu_template`)
- `scripts/create-ubuntu-template.sh`

The script performs the same steps as the old playbook flow: download Ubuntu cloud image, `qm create`, `qm importdisk`, attach disk/cloud-init, set boot+serial, apply cloud-init options, and `qm template`.

---

## 1) Configure template variables

Set these values in `terraform.tfvars` (or keep the defaults if they match your environment):

```hcl
create_ubuntu_template         = true
ubuntu_template_vmid           = 901
ubuntu_template_name           = "ubuntu-noble-cloud"
ubuntu_template_storage        = "local-lvm"
ubuntu_template_ubuntu_release = "noble"
ubuntu_template_disk_resize    = "+32G"
ubuntu_template_memory         = 6144
ubuntu_template_cores          = 4
ubuntu_template_ssh_public_key_path = "~/.ssh/id_ed25519.pub"
```

Defaults are based on the latest successful command history entry in `playbooks/proxmox/README.md` dated `02/22/2026`.

---

## 2) Build or refresh the template

From `terraform/`:

```bash
terraform apply -target=terraform_data.ubuntu_template
```

Or run a normal apply (`terraform apply`) if you also want Terraform to manage VM clones in the same run.

---

## Notes

- The template build is **optional**; it only runs when `create_ubuntu_template = true`.
- If template settings change, Terraform replaces `terraform_data.ubuntu_template` and reruns the `qm` commands.
- The script recreates the VM/template for the configured `ubuntu_template_vmid` to guarantee the final template matches the declared settings.
- VM clone modules use `ubuntu_template_name` when template creation is enabled, so the clone source stays in sync.
