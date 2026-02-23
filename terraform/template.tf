locals {
  # Keep existing VM clone behavior unchanged unless template creation is enabled.
  nonprod_template_name = var.create_ubuntu_template ? var.ubuntu_template_name : var.template_name

  ubuntu_template_storage             = trimspace(var.ubuntu_template_storage) != "" ? var.ubuntu_template_storage : var.storage
  ubuntu_template_proxmox_ssh_host    = trimspace(var.ubuntu_template_proxmox_ssh_host) != "" ? var.ubuntu_template_proxmox_ssh_host : var.proxmox_node
  ubuntu_template_ssh_public_key_path = trimspace(var.ubuntu_template_ssh_public_key_path) != "" ? var.ubuntu_template_ssh_public_key_path : var.ssh_public_key_path
}

resource "terraform_data" "ubuntu_template" {
  count = var.create_ubuntu_template ? 1 : 0

  triggers_replace = {
    proxmox_ssh_host        = local.ubuntu_template_proxmox_ssh_host
    proxmox_ssh_user        = var.ubuntu_template_proxmox_ssh_user
    proxmox_ssh_port        = tostring(var.ubuntu_template_proxmox_ssh_port)
    proxmox_ssh_private_key = var.ubuntu_template_proxmox_ssh_private_key_path

    vmid              = tostring(var.ubuntu_template_vmid)
    template_name     = var.ubuntu_template_name
    storage           = local.ubuntu_template_storage
    ubuntu_release    = var.ubuntu_template_ubuntu_release
    template_resize   = var.ubuntu_template_disk_resize
    memory            = tostring(var.ubuntu_template_memory)
    cores             = tostring(var.ubuntu_template_cores)
    bridge            = var.ubuntu_template_bridge
    ipconfig0         = var.ubuntu_template_ipconfig0
    ciuser            = var.ubuntu_template_ciuser
    cipassword_sha256 = sha256(var.ubuntu_template_cipassword)
    work_dir          = var.ubuntu_template_work_dir

    ssh_public_key_path = local.ubuntu_template_ssh_public_key_path
    ssh_public_key_sha  = var.create_ubuntu_template ? filesha256(pathexpand(local.ubuntu_template_ssh_public_key_path)) : ""
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "/bin/bash ${path.module}/scripts/create-ubuntu-template.sh"

    environment = {
      PROXMOX_SSH_HOST             = local.ubuntu_template_proxmox_ssh_host
      PROXMOX_SSH_USER             = var.ubuntu_template_proxmox_ssh_user
      PROXMOX_SSH_PORT             = tostring(var.ubuntu_template_proxmox_ssh_port)
      PROXMOX_SSH_PRIVATE_KEY_PATH = var.ubuntu_template_proxmox_ssh_private_key_path

      UBUNTU_TEMPLATE_VMID                = tostring(var.ubuntu_template_vmid)
      UBUNTU_TEMPLATE_NAME                = var.ubuntu_template_name
      UBUNTU_TEMPLATE_STORAGE             = local.ubuntu_template_storage
      UBUNTU_TEMPLATE_UBUNTU_RELEASE      = var.ubuntu_template_ubuntu_release
      UBUNTU_TEMPLATE_DISK_RESIZE         = var.ubuntu_template_disk_resize
      UBUNTU_TEMPLATE_MEMORY              = tostring(var.ubuntu_template_memory)
      UBUNTU_TEMPLATE_CORES               = tostring(var.ubuntu_template_cores)
      UBUNTU_TEMPLATE_BRIDGE              = var.ubuntu_template_bridge
      UBUNTU_TEMPLATE_IPCONFIG0           = var.ubuntu_template_ipconfig0
      UBUNTU_TEMPLATE_CIUSER              = var.ubuntu_template_ciuser
      UBUNTU_TEMPLATE_CIPASSWORD          = var.ubuntu_template_cipassword
      UBUNTU_TEMPLATE_SSH_PUBLIC_KEY_PATH = local.ubuntu_template_ssh_public_key_path
      UBUNTU_TEMPLATE_WORK_DIR            = var.ubuntu_template_work_dir
    }
  }
}
