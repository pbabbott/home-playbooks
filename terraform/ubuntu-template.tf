locals {
  # Use one SSH public key path for cloud-init everywhere (template + cloned VMs).
  cloud_init_public_key_path = pathexpand(var.ssh_public_key_path)

  # Clone modules automatically use the template built in this stack when enabled.
  nonprod_template_name = var.create_ubuntu_template ? var.ubuntu_template_name : var.template_name

  # Readable aliases for optional overrides.
  template_storage      = trimspace(var.ubuntu_template_storage) != "" ? var.ubuntu_template_storage : var.storage
  template_proxmox_host = trimspace(var.ubuntu_template_proxmox_ssh_host) != "" ? var.ubuntu_template_proxmox_ssh_host : var.proxmox_node

  # Ubuntu cloud image metadata.
  template_image_name = "${var.ubuntu_template_ubuntu_release}-server-cloudimg-amd64.img"
  template_image_url  = "https://cloud-images.ubuntu.com/${var.ubuntu_template_ubuntu_release}/current/${local.template_image_name}"
  template_image_path = "${var.ubuntu_template_work_dir}/${local.template_image_name}"
}

# Provider gap: ensure the cloud image file exists on the Proxmox host.
resource "terraform_data" "ubuntu_template_image" {
  count = var.create_ubuntu_template ? 1 : 0

  triggers_replace = {
    proxmox_ssh_host = local.template_proxmox_host
    proxmox_ssh_user = var.ubuntu_template_proxmox_ssh_user
    proxmox_ssh_port = tostring(var.ubuntu_template_proxmox_ssh_port)

    work_dir   = var.ubuntu_template_work_dir
    image_name = local.template_image_name
    image_url  = local.template_image_url
    image_path = local.template_image_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$PROXMOX_SSH_PORT")
      remote_target="$PROXMOX_SSH_USER@$PROXMOX_SSH_HOST"
      "${ssh_cmd[@]}" "$remote_target" "mkdir -p \"$WORK_DIR\" && if [ ! -f \"$IMAGE_PATH\" ]; then wget -q -O \"$IMAGE_PATH\" \"$IMAGE_URL\"; fi"
    EOT

    environment = {
      PROXMOX_SSH_HOST = local.template_proxmox_host
      PROXMOX_SSH_USER = var.ubuntu_template_proxmox_ssh_user
      PROXMOX_SSH_PORT = tostring(var.ubuntu_template_proxmox_ssh_port)

      WORK_DIR   = var.ubuntu_template_work_dir
      IMAGE_PATH = local.template_image_path
      IMAGE_URL  = local.template_image_url
    }
  }
}

resource "proxmox_vm_qemu" "ubuntu_template" {
  count = var.create_ubuntu_template ? 1 : 0

  vmid        = var.ubuntu_template_vmid
  name        = var.ubuntu_template_name
  target_node = var.proxmox_node

  cores  = var.ubuntu_template_cores
  memory = var.ubuntu_template_memory

  os_type  = "cloud-init"
  scsihw   = "virtio-scsi-pci"
  vm_state = "stopped"
  agent    = 0
  boot     = "order=scsi0"

  network {
    model  = "virtio"
    bridge = var.ubuntu_template_bridge
  }

  # Attach the downloaded cloud image as the primary boot disk.
  disk {
    slot        = "scsi0"
    type        = "disk"
    passthrough = true
    disk_file   = local.template_image_path
  }

  # Add a cloud-init drive to the template.
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = local.template_storage
  }

  ipconfig0 = var.ubuntu_template_ipconfig0

  ciuser     = trimspace(var.ubuntu_template_ciuser) != "" ? var.ubuntu_template_ciuser : null
  cipassword = trimspace(var.ubuntu_template_cipassword) != "" ? var.ubuntu_template_cipassword : null
  sshkeys    = file(local.cloud_init_public_key_path)

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }

  # Recreate when core template-shaping inputs change.
  force_recreate_on_change_of = sha256(jsonencode({
    image_path     = local.template_image_path
    image_url      = local.template_image_url
    disk_resize    = var.ubuntu_template_disk_resize
    bridge         = var.ubuntu_template_bridge
    ipconfig0      = var.ubuntu_template_ipconfig0
    ciuser         = var.ubuntu_template_ciuser
    cipassword_sha = sha256(var.ubuntu_template_cipassword)
    memory         = tostring(var.ubuntu_template_memory)
    cores          = tostring(var.ubuntu_template_cores)
    ssh_key_sha    = filesha256(local.cloud_init_public_key_path)
  }))

  # Provider gap: no first-class "qm template" conversion or disk resize hook.
  provisioner "local-exec" {
    when        = create
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$PROXMOX_SSH_PORT")
      remote_target="$PROXMOX_SSH_USER@$PROXMOX_SSH_HOST"

      if [[ -n "$UBUNTU_TEMPLATE_DISK_RESIZE" ]]; then
        "${ssh_cmd[@]}" "$remote_target" "qm resize \"$UBUNTU_TEMPLATE_VMID\" scsi0 \"$UBUNTU_TEMPLATE_DISK_RESIZE\""
      fi

      "${ssh_cmd[@]}" "$remote_target" "qm template \"$UBUNTU_TEMPLATE_VMID\""
    EOT

    environment = {
      PROXMOX_SSH_HOST = local.template_proxmox_host
      PROXMOX_SSH_USER = var.ubuntu_template_proxmox_ssh_user
      PROXMOX_SSH_PORT = tostring(var.ubuntu_template_proxmox_ssh_port)

      UBUNTU_TEMPLATE_VMID        = tostring(var.ubuntu_template_vmid)
      UBUNTU_TEMPLATE_DISK_RESIZE = var.ubuntu_template_disk_resize
    }
  }

  depends_on = [terraform_data.ubuntu_template_image]
}
