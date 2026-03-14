# SSH public key for cloud-init (cloned VMs). Template is created by playbooks/proxmox/create-ubuntu-template.yml before Terraform runs.
locals {
  cloud_init_public_key_path = pathexpand(var.ssh_public_key_path)
  cloud_init_public_key      = fileexists(local.cloud_init_public_key_path) ? trimspace(file(local.cloud_init_public_key_path)) : ""
}

# Resolve template name to VM ID for BPG provider clone (template must exist on proxmox_node).
data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node
  filter {
    name   = "name"
    values = [var.template_name]
  }
  filter {
    name   = "template"
    values = [true]
  }
}

locals {
  template_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
  nonprod_ip_configs = {
    for name in keys(var.nonprod_vms) :
    name => "ip=${var.nonprod_static_ips[name]}/22,gw=${var.nonprod_gateway}"
  }
}

# Non-prod fleet (300 range): 4 VMs created from var.nonprod_vms
module "nonprod_vm" {
  for_each = var.nonprod_vms

  source = "./modules/vm"

  vmid                  = each.value
  name                  = each.key
  target_node           = var.proxmox_node
  template_id           = local.template_id
  cores                 = 4
  cpu_type              = "host"
  memory                = 6144
  memory_floating       = 512
  disk_size             = "32G"
  storage               = var.storage
  enable_ssd_data_disk  = var.enable_nonprod_worker_ssd_data_disk && can(regex("-worker-", each.key))
  ssd_data_disk_storage = trimspace(var.storage_ssd) != "" ? var.storage_ssd : var.storage
  ssd_data_disk_size    = var.nonprod_worker_ssd_data_disk_size
  bridge                = var.bridge
  ssh_public_key        = local.cloud_init_public_key
  cloudinit_username    = "firebolt"
  ip_config             = local.nonprod_ip_configs[each.key]
}
