# Base VM template 900 (stock Ubuntu 24.04 cloud image + cloud-init), see modules/ubuntu-template.
# Layer 2 (901, tpl-k3s-noble) is built from it by packer/k3s-template.

module "base_template" {
  source = "../modules/ubuntu-template"

  node_name       = var.proxmox_node
  vm_id           = 900
  ssh_public_keys = [trimspace(file("~/.ssh/id_ed25519.pub"))]
}

moved {
  from = proxmox_virtual_environment_download_file.ubuntu_noble
  to   = module.base_template.proxmox_virtual_environment_download_file.image
}

moved {
  from = proxmox_virtual_environment_vm.tpl_ubuntu_noble_base
  to   = module.base_template.proxmox_virtual_environment_vm.base
}
