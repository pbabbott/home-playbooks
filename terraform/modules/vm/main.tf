resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vmid != 0 ? var.vmid : null # null = auto-assign
  started   = var.started

  # Avoid in-place updates touching ide2 (cloud-init CDROM); Proxmox rejects "unable to change media type".
  # To change SSH keys, ip_config, or cloudinit_username, destroy and recreate the VM or temporarily remove this block.
  # Disks come from the template clone; do not manage disk blocks here or Terraform may try to reconcile them away.
  lifecycle {
    ignore_changes = [initialization, disk]
  }

  clone {
    vm_id = var.template_id
    full  = true
  }

  # Debian 12 / Ubuntu: serial device required to avoid kernel panic on disk resize (BPG known issue)
  serial_device {}

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  initialization {
    # Identity is set per VM at create time (the gen3 template carries no keys). Skipped when no keys are given
    # (gen2/chimaera template has them baked in).
    dynamic "user_account" {
      for_each = length(var.ssh_public_keys) > 0 ? [1] : []
      content {
        username = var.username
        keys     = var.ssh_public_keys
      }
    }

    ip_config {
      ipv4 {
        address = "${var.ip_address}/22"
        gateway = var.gateway
      }
    }
  }

  operating_system {
    type = "l26"
  }
}
