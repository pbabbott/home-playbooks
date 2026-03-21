# Non-prod fleet (300 range): 4 VMs created from var.nonprod_vms
module "nonprod_vm" {
  for_each = var.nonprod_vms

  source = "./modules/vm"

  vmid            = each.value.vmid
  name            = each.key
  target_node     = var.proxmox_node
  ip_address      = each.value.ip
  template_id     = 901
  memory_floating = each.value.memory_floating
}

# Prod fleet (200 range): inventories/prod/hosts.yml
module "prod_vm" {
  for_each = var.prod_vms

  source = "./modules/vm"

  vmid            = each.value.vmid
  name            = each.key
  target_node     = var.proxmox_node
  ip_address      = each.value.ip
  template_id     = 901
  memory_floating = each.value.memory_floating
}

module "haproxy" {
  source = "./modules/haproxy"
}
