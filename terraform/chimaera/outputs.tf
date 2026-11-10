output "k3s_vm_ids" {
  description = "Proxmox VM IDs for the gen3 k3s nodes on chimaera"
  value       = { for k, m in module.k3s_vm : k => m.vm_id }
}
