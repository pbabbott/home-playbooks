# Getting started with Terraform (Proxmox)

Run all commands from the **terraform** directory (`cd terraform` from repo root).

---

## First-time setup

1. **Proxmox API token**  
   In Proxmox: Datacenter → Permissions → Users → Add API Token. Grant VM create/delete/clone on the target node and storage.

2. **Terraform variables**  
   Copy the example tfvars and fill in your values (do not commit real secrets):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars: API URL/token plus template/VM settings (template name, storage, SSH key paths, etc.).
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
 
   ```
---

## Create or refresh the Ubuntu template

Template creation is Terraform-managed in this directory. After setting template variables in `terraform.tfvars` (especially `create_ubuntu_template = true`), run:

```bash
terraform apply -target=terraform_data.ubuntu_template
```

For full variable list and behavior, see [create-ubuntu-template.md](create-ubuntu-template.md).


## Common commands

| Command | Purpose |
|--------|---------|
| `terraform init` | Download providers and prepare the working directory. Run after clone or when changing provider/backend. |
| `terraform plan` | Show what would change (no changes applied). Use before apply. |
| `terraform apply` | Create or update template/VM resources to match the config. Use `-auto-approve` to skip the prompt. |
| `terraform apply -destroy` | Destroy all resources managed by this config. |
| `terraform destroy` | Same as `apply -destroy`. |
| `terraform output` | List output values (e.g. VM IDs, names, IPs). |
| `terraform output -json` | Outputs in JSON (useful for scripts or Ansible). |
| `terraform fmt` | Format `.tf` files to standard style. |
| `terraform validate` | Check config syntax and internal consistency. |

---

## Typical workflows

**Preview changes before applying**
```bash
terraform plan
terraform apply
```

**Destroy a single VM**  
Comment out or remove its module block in `main.tf`, then:
```bash
terraform plan   # should show the VM being destroyed
terraform apply
```

**See VM details for Ansible**
```bash
terraform output
terraform output nonprod_vm_names
terraform output nonprod_vm_ip_addresses
```

**Re-run after editing tfvars or adding a new VM**
```bash
terraform plan
terraform apply
```

**Format and validate**
```bash
terraform fmt -recursive
terraform validate
```

---

## State

State is stored locally by default (no remote backend). Keep backups of `terraform.tfstate` if you rely on it; do not commit it if it might contain sensitive data.
