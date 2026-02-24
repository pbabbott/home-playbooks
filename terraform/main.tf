# Non-prod fleet (300 range): 4 VMs created from var.nonprod_vms
module "nonprod_vm" {
  for_each = var.nonprod_vms

  source = "./modules/vm"

  vmid           = each.value
  name           = each.key
  target_node   = var.proxmox_node
  template_name = local.nonprod_template_name
  cores         = 2
  memory        = 2048
  disk_size     = "20G"
  storage       = var.storage
  bridge        = var.bridge
  ssh_public_key = file(local.cloud_init_public_key_path)
  ip_config     = "ip=dhcp"

  depends_on = [proxmox_vm_qemu.ubuntu_template]
}

# Optional: VM on onboard SSD — uncomment and add to nonprod_vms or create a separate module
# module "nonprod_vm_ssd" {
#   for_each = { "tf-nonprod-k8s-worker-4" = 305 }
#   source   = "./modules/vm"
#   vmid     = each.value
#   name     = each.key
#   target_node   = var.proxmox_node
#   template_name = var.template_name
#   cores         = 2
#   memory        = 2048
#   disk_size     = "20G"
#   storage       = var.storage_ssd != "" ? var.storage_ssd : var.storage
#   bridge        = var.bridge
#   ssh_public_key = file(local.cloud_init_public_key_path)
#   ip_config     = "ip=dhcp"
# }
