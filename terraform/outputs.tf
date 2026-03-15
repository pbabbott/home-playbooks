output "nonprod_vm_ids" {
  description = "Proxmox VM IDs for non-prod fleet (300 range)"
  value       = { for k, m in module.nonprod_vm : k => m.vm_id }
}

output "nonprod_vm_names" {
  description = "Names of non-prod VMs"
  value       = { for k, m in module.nonprod_vm : k => m.vm_name }
}

output "nonprod_vm_ip_addresses" {
  description = "IP addresses of non-prod VMs (if reported by qemu-guest-agent)"
  value       = { for k, m in module.nonprod_vm : k => m.ip_address }
}
