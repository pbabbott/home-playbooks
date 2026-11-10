# Non-prod fleet (300 range): 4 VMs created from var.nonprod_vms
module "nonprod_vm" {
  for_each = var.nonprod_vms

  source = "../modules/vm"

  vmid        = each.value.vmid
  name        = each.key
  target_node = var.proxmox_node
  ip_address  = each.value.ip
  template_id = 901
  memory      = each.value.memory
  started     = false
  on_boot     = false
}

# Prod fleet (200 range): inventories/prod/hosts.yml
module "prod_vm" {
  for_each = var.prod_vms

  source = "../modules/vm"

  vmid        = each.value.vmid
  name        = each.key
  target_node = var.proxmox_node
  ip_address  = each.value.ip
  template_id = 901
  memory      = each.value.memory
  started     = false # gen2 retired 2026-11-09; desired state is off (rollback only)
  on_boot     = false
}

# The gen2 HAProxy LXC (192.168.6.28, VMID 208) was retired in Phase 9 (stopped 2026-11-09) and its module removed here.
# Applying this destroys the LXC. Gen3 ingress is terraform/hogwarts (LXC 213, .29), which still uses ../modules/haproxy.
