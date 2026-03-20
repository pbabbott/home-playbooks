# Getting started with Terraform (Proxmox)

Run all commands from the `terraform/` directory (`cd terraform` from repo root).

---

## Read this first

For a smoother first run, skim these docs in order:

1. [terraform-overview.md](terraform-overview.md) - code layout and variable flow
2. [preferences-and-conventions.md](preferences-and-conventions.md) - VM ID, naming, and storage conventions

---

## First-time setup

1. **Create a Proxmox API token**  
   In Proxmox: Datacenter → Permissions → Users → Add API Token. Grant VM create/delete/clone rights on the target node and storage.  
   If `terraform plan` later fails with **501 no such file '/json/access/users'**, see [proxmox-api-token.md](proxmox-api-token.md) (disable Privilege Separation or grant Sys.Audit).

2. **Create `terraform.tfvars` from the example**  
   Copy the example values and fill in your environment-specific settings:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars: API URL/token, node, template settings, storage, SSH key path, etc.
   ```

3. **Initialize the working directory**
   ```bash
   terraform init
   ```

4. **Run a quick config sanity check**
   ```bash
   terraform validate
   ```

---

## Ubuntu template (prerequisite)

The cloud-init template must exist on Proxmox before Terraform can create VMs. Create or refresh it with the Ansible playbook (run from repo root):

```bash
ansible-playbook -i inventory.yml playbooks/proxmox/create-ubuntu-template.yml
```

Set `template_name` in `terraform.tfvars` to match the template name produced by that playbook (e.g. `tf-template-ubuntu-noble`).

---

## Common commands

| Command | Purpose |
|--------|---------|
| `terraform init` | Download providers and prepare the working directory. Run after clone or when changing provider/backend settings. |
| `terraform plan` | Show what would change (no changes applied). Run before apply. |
| `terraform apply` | Create or update VM resources to match config. Use `-auto-approve` to skip confirmation. |
| `terraform apply -destroy` | Destroy all resources managed by this config. |
| `terraform destroy` | Same as `terraform apply -destroy`. |
| `terraform output` | List output values (VM IDs, names, IPs). |
| `terraform output -json` | Output values as JSON for scripting/Ansible inventory generation. |
| `terraform fmt -recursive` | Format `.tf` files to standard style. |
| `terraform validate` | Check syntax and internal consistency. |

---

## Typical workflows

**Preview and apply**
```bash
terraform plan
terraform apply
```

**Destroy a single non-prod VM**  
Remove that VM's entry from the `nonprod_vms` map (usually in `terraform.tfvars`, or in the default map in `variables.tf`), then:
```bash
terraform plan   # should show only that VM being destroyed
terraform apply
```

**Inspect outputs for Ansible**
```bash
terraform output
terraform output nonprod_vm_names
```
IPs are set in `nonprod_static_ips` / `prod_static_ips` (e.g. `terraform.tfvars`), not as Terraform outputs.

**After editing tfvars or adding/removing VMs**
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

State is local by default (no remote backend configured here). Back up `terraform.tfstate` if needed, and do not commit state files if they may contain sensitive values. If apply crashed but VMs exist in Proxmox, see [terraform-overview.md](terraform-overview.md#recovery-vms-exist-in-proxmox-but-terraform-state-is-empty) for import steps.
