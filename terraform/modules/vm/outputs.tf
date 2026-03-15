output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

# IP may be populated by qemu-guest-agent if available; otherwise null
output "ip_address" {
  description = "Primary IP address from qemu-guest-agent (if available)"
  value       = try(one(flatten(proxmox_virtual_environment_vm.vm.ipv4_addresses)), null)
}
