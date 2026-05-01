resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vmid != 0 ? var.vmid : null # null = auto-assign

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
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
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
