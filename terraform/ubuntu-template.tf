locals {
  # Use one SSH public key path for cloud-init everywhere (template + cloned VMs).
  cloud_init_public_key_path = pathexpand(var.ssh_public_key_path)
  cloud_init_public_key      = fileexists(local.cloud_init_public_key_path) ? trimspace(file(local.cloud_init_public_key_path)) : ""

  # When template creation is enabled, clones default to the selected primary release.
  nonprod_template_name = var.create_ubuntu_template ? "${var.ubuntu_template_name_prefix}-${var.ubuntu_template_primary_release}" : var.template_name

  # Readable aliases for optional overrides.
  template_storage      = trimspace(var.ubuntu_template_storage) != "" ? var.ubuntu_template_storage : var.storage
  template_proxmox_host = trimspace(var.ubuntu_template_proxmox_ssh_host) != "" ? var.ubuntu_template_proxmox_ssh_host : var.proxmox_node
  template_ssh_key_path = trimspace(var.ubuntu_template_ssh_public_key_path_on_proxmox)

  # Prefer local public key content when present; otherwise optionally use a key file that already exists on Proxmox.
  template_use_local_ssh_key = local.cloud_init_public_key != "" && local.template_ssh_key_path == ""

  # Opinionated template model: release->vmid, with derived name/image values.
  ubuntu_templates = {
    for release, vmid in var.ubuntu_template_vmids : release => {
      vmid       = vmid
      name       = "${var.ubuntu_template_name_prefix}-${release}"
      image_name = "${release}-server-cloudimg-amd64.img"
      image_url  = "https://cloud-images.ubuntu.com/${release}/current/${release}-server-cloudimg-amd64.img"
      image_path = "${var.ubuntu_template_work_dir}/${release}-server-cloudimg-amd64.img"
    }
  }
}

# Provider gap: ensure the cloud image file exists on the Proxmox host.
resource "terraform_data" "ubuntu_template_image" {
  for_each = var.create_ubuntu_template ? local.ubuntu_templates : {}

  triggers_replace = {
    release          = each.key
    vmid             = tostring(each.value.vmid)
    proxmox_ssh_host = local.template_proxmox_host
    proxmox_ssh_user = var.ubuntu_template_proxmox_ssh_user
    proxmox_ssh_port = tostring(var.ubuntu_template_proxmox_ssh_port)

    work_dir   = var.ubuntu_template_work_dir
    image_name = each.value.image_name
    image_url  = each.value.image_url
    image_path = each.value.image_path
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
      IMAGE_PATH = each.value.image_path
      IMAGE_URL  = each.value.image_url
    }
  }
}

resource "proxmox_vm_qemu" "ubuntu_template" {
  for_each = var.create_ubuntu_template ? local.ubuntu_templates : {}

  vmid        = each.value.vmid
  name        = each.value.name
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
    slot = "scsi0"
    type = "ignore"
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
  sshkeys    = local.template_use_local_ssh_key ? local.cloud_init_public_key : null

  serial {
    id   = 0
    type = "socket"
  }

  vga {
    type = "serial0"
  }

  # Recreate when core template-shaping inputs change.
  force_recreate_on_change_of = sha256(jsonencode({
    release        = each.key
    vmid           = tostring(each.value.vmid)
    template_name  = each.value.name
    image_path     = each.value.image_path
    image_url      = each.value.image_url
    storage        = local.template_storage
    ssh_key_path   = local.template_ssh_key_path
    disk_resize    = var.ubuntu_template_disk_resize
    bridge         = var.ubuntu_template_bridge
    ipconfig0      = var.ubuntu_template_ipconfig0
    ciuser         = var.ubuntu_template_ciuser
    cipassword_sha = sha256(var.ubuntu_template_cipassword)
    memory         = tostring(var.ubuntu_template_memory)
    cores          = tostring(var.ubuntu_template_cores)
    ssh_key_sha    = local.cloud_init_public_key != "" ? sha256(local.cloud_init_public_key) : ""
  }))

  # Provider gap: no first-class "qm template" conversion or disk resize hook.
  provisioner "local-exec" {
    when        = create
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$PROXMOX_SSH_PORT")
      remote_target="$PROXMOX_SSH_USER@$PROXMOX_SSH_HOST"

      "${ssh_cmd[@]}" "$remote_target" "qm importdisk \"$UBUNTU_TEMPLATE_VMID\" \"$UBUNTU_TEMPLATE_IMAGE_PATH\" \"$UBUNTU_TEMPLATE_STORAGE\""
      "${ssh_cmd[@]}" "$remote_target" "qm set \"$UBUNTU_TEMPLATE_VMID\" --scsihw virtio-scsi-pci --scsi0 \"$UBUNTU_TEMPLATE_STORAGE:vm-$UBUNTU_TEMPLATE_VMID-disk-0\""

      if [[ -n "$UBUNTU_TEMPLATE_DISK_RESIZE" ]]; then
        "${ssh_cmd[@]}" "$remote_target" "qm resize \"$UBUNTU_TEMPLATE_VMID\" scsi0 \"$UBUNTU_TEMPLATE_DISK_RESIZE\""
      fi

      if [[ -n "$UBUNTU_TEMPLATE_SSH_KEY_PATH_ON_PROXMOX" ]]; then
        "${ssh_cmd[@]}" "$remote_target" "qm set \"$UBUNTU_TEMPLATE_VMID\" --sshkey \"$UBUNTU_TEMPLATE_SSH_KEY_PATH_ON_PROXMOX\""
      fi

      "${ssh_cmd[@]}" "$remote_target" "qm template \"$UBUNTU_TEMPLATE_VMID\""
    EOT

    environment = {
      PROXMOX_SSH_HOST = local.template_proxmox_host
      PROXMOX_SSH_USER = var.ubuntu_template_proxmox_ssh_user
      PROXMOX_SSH_PORT = tostring(var.ubuntu_template_proxmox_ssh_port)

      UBUNTU_TEMPLATE_VMID        = tostring(each.value.vmid)
      UBUNTU_TEMPLATE_STORAGE     = local.template_storage
      UBUNTU_TEMPLATE_IMAGE_PATH  = each.value.image_path
      UBUNTU_TEMPLATE_DISK_RESIZE = var.ubuntu_template_disk_resize
      UBUNTU_TEMPLATE_SSH_KEY_PATH_ON_PROXMOX = local.template_ssh_key_path
    }
  }

  depends_on = [terraform_data.ubuntu_template_image]
}
