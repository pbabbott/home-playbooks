output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_vm_qemu.vm.name
}

# IP may be populated by qemu-guest-agent if available; otherwise null
output "ip_address" {
  description = "Primary IP address from qemu-guest-agent (if available)"
  value       = try(proxmox_vm_qemu.vm.default_ipv4_address, null)
}
