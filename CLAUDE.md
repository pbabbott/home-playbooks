## Operational Guidelines

Be brief.

## Reference

- `./archive/` - Legacy playbooks, not in use. Simply here for reference purposes.
- `./playbooks/` - Current ansible playbooks
- `./terraform` - Terraform codebase manages gen2 prod and non-prod vms on a proxmox installation, as well as as an lxc for ha proxy.


### Important playbooks

- `./playbooks/kubernetes-gen2/` - This is where my current gen2 prod and non-prod clusters are bootstrapped.
- `./playbooks/dns` - These playbooks manage pihole, my preferred dns server.