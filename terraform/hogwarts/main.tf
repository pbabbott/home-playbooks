# gen3 k8s fleet on hogwarts. No VMs defined yet.
# Reuse the shared module, e.g.:
#
# module "prod_vm" {
#   for_each    = var.prod_vms
#   source      = "../modules/vm"
#   vmid        = each.value.vmid
#   name        = each.key
#   target_node = var.proxmox_node
#   ip_address  = each.value.ip
#   template_id = <hogwarts template ID>
#   memory      = each.value.memory
# }
