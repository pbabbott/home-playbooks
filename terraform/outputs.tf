output "nonprod_vm_ids" {
  description = "Proxmox VM IDs for non-prod fleet (300 range)"
  value       = { for k, m in module.nonprod_vm : k => m.vm_id }
}

output "nonprod_vm_names" {
  description = "Names of non-prod VMs"
  value       = { for k, m in module.nonprod_vm : k => m.vm_name }
}

# output "prod_vm_ids" {
#   description = "Proxmox VM IDs for prod fleet (200 range)"
#   value       = { for k, m in module.prod_vm : k => m.vm_id }
# }

# output "prod_vm_names" {
#   description = "Names of prod VMs"
#   value       = { for k, m in module.prod_vm : k => m.vm_name }
# }
