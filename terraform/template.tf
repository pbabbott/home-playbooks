locals {
  # Keep existing VM clone behavior unchanged unless template creation is enabled.
  nonprod_template_name = var.create_ubuntu_template ? var.ubuntu_template_name : var.template_name

  ubuntu_template_storage             = trimspace(var.ubuntu_template_storage) != "" ? var.ubuntu_template_storage : var.storage
  ubuntu_template_proxmox_ssh_host    = trimspace(var.ubuntu_template_proxmox_ssh_host) != "" ? var.ubuntu_template_proxmox_ssh_host : var.proxmox_node
  ubuntu_template_ssh_public_key_path = trimspace(var.ubuntu_template_ssh_public_key_path) != "" ? var.ubuntu_template_ssh_public_key_path : var.ssh_public_key_path
  ubuntu_template_ssh_private_key_path = trimspace(var.ubuntu_template_proxmox_ssh_private_key_path) != "" ? pathexpand(var.ubuntu_template_proxmox_ssh_private_key_path) : ""
  ubuntu_template_image_name           = "${var.ubuntu_template_ubuntu_release}-server-cloudimg-amd64.img"
  ubuntu_template_image_url            = "https://cloud-images.ubuntu.com/${var.ubuntu_template_ubuntu_release}/current/${local.ubuntu_template_image_name}"
  ubuntu_template_image_path           = "${var.ubuntu_template_work_dir}/${local.ubuntu_template_image_name}"
  ubuntu_template_ssh_key_sha          = var.create_ubuntu_template ? filesha256(pathexpand(local.ubuntu_template_ssh_public_key_path)) : ""
}

resource "terraform_data" "ubuntu_template_image" {
  count = var.create_ubuntu_template ? 1 : 0

  triggers_replace = {
    proxmox_ssh_host        = local.ubuntu_template_proxmox_ssh_host
    proxmox_ssh_user        = var.ubuntu_template_proxmox_ssh_user
    proxmox_ssh_port        = tostring(var.ubuntu_template_proxmox_ssh_port)
    proxmox_ssh_private_key = local.ubuntu_template_ssh_private_key_path

    work_dir   = var.ubuntu_template_work_dir
    image_name = local.ubuntu_template_image_name
    image_url  = local.ubuntu_template_image_url
    image_path = local.ubuntu_template_image_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$PROXMOX_SSH_PORT")
      if [[ -n "$PROXMOX_SSH_PRIVATE_KEY_PATH" ]]; then
        if [[ ! -f "$PROXMOX_SSH_PRIVATE_KEY_PATH" ]]; then
          echo "SSH private key file not found: $PROXMOX_SSH_PRIVATE_KEY_PATH" >&2
          exit 1
        fi
        ssh_cmd+=(-i "$PROXMOX_SSH_PRIVATE_KEY_PATH")
      fi

      remote_target="$PROXMOX_SSH_USER@$PROXMOX_SSH_HOST"
      "${ssh_cmd[@]}" "$remote_target" "mkdir -p \"$WORK_DIR\" && if [ ! -f \"$IMAGE_PATH\" ]; then wget -q -O \"$IMAGE_PATH\" \"$IMAGE_URL\"; fi"
    EOT

    environment = {
      PROXMOX_SSH_HOST             = local.ubuntu_template_proxmox_ssh_host
      PROXMOX_SSH_USER             = var.ubuntu_template_proxmox_ssh_user
      PROXMOX_SSH_PORT             = tostring(var.ubuntu_template_proxmox_ssh_port)
      PROXMOX_SSH_PRIVATE_KEY_PATH = local.ubuntu_template_ssh_private_key_path

      WORK_DIR   = var.ubuntu_template_work_dir
      IMAGE_PATH = local.ubuntu_template_image_path
      IMAGE_URL  = local.ubuntu_template_image_url
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

  # Attach the downloaded cloud image directly as scsi0.
  disk {
    slot        = "scsi0"
    type        = "disk"
    passthrough = true
    disk_file   = local.ubuntu_template_image_path
  }

  # Add cloud-init drive on IDE2.
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = local.ubuntu_template_storage
  }

  ipconfig0 = var.ubuntu_template_ipconfig0

  ciuser     = trimspace(var.ubuntu_template_ciuser) != "" ? var.ubuntu_template_ciuser : null
  cipassword = trimspace(var.ubuntu_template_cipassword) != "" ? var.ubuntu_template_cipassword : null
  sshkeys    = file(pathexpand(local.ubuntu_template_ssh_public_key_path))

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }

  # Recreate the template VM when core image/template-shaping inputs change.
  force_recreate_on_change_of = sha256(jsonencode({
    image_path     = local.ubuntu_template_image_path
    image_url      = local.ubuntu_template_image_url
    disk_resize    = var.ubuntu_template_disk_resize
    bridge         = var.ubuntu_template_bridge
    ipconfig0      = var.ubuntu_template_ipconfig0
    ciuser         = var.ubuntu_template_ciuser
    cipassword_sha = sha256(var.ubuntu_template_cipassword)
    memory         = tostring(var.ubuntu_template_memory)
    cores          = tostring(var.ubuntu_template_cores)
    ssh_key_sha    = local.ubuntu_template_ssh_key_sha
  }))

  provisioner "local-exec" {
    when        = create
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$PROXMOX_SSH_PORT")
      if [[ -n "$PROXMOX_SSH_PRIVATE_KEY_PATH" ]]; then
        if [[ ! -f "$PROXMOX_SSH_PRIVATE_KEY_PATH" ]]; then
          echo "SSH private key file not found: $PROXMOX_SSH_PRIVATE_KEY_PATH" >&2
          exit 1
        fi
        ssh_cmd+=(-i "$PROXMOX_SSH_PRIVATE_KEY_PATH")
      fi

      remote_target="$PROXMOX_SSH_USER@$PROXMOX_SSH_HOST"

      if [[ -n "$UBUNTU_TEMPLATE_DISK_RESIZE" ]]; then
        "${ssh_cmd[@]}" "$remote_target" "qm resize \"$UBUNTU_TEMPLATE_VMID\" scsi0 \"$UBUNTU_TEMPLATE_DISK_RESIZE\""
      fi

      "${ssh_cmd[@]}" "$remote_target" "qm template \"$UBUNTU_TEMPLATE_VMID\""
    EOT

    environment = {
      PROXMOX_SSH_HOST             = local.ubuntu_template_proxmox_ssh_host
      PROXMOX_SSH_USER             = var.ubuntu_template_proxmox_ssh_user
      PROXMOX_SSH_PORT             = tostring(var.ubuntu_template_proxmox_ssh_port)
      PROXMOX_SSH_PRIVATE_KEY_PATH = local.ubuntu_template_ssh_private_key_path

      UBUNTU_TEMPLATE_VMID        = tostring(var.ubuntu_template_vmid)
      UBUNTU_TEMPLATE_DISK_RESIZE = var.ubuntu_template_disk_resize
    }
  }

  depends_on = [terraform_data.ubuntu_template_image]
}
