locals {
  ssd_data_disk_storage = trimspace(var.ssd_data_disk_storage) != "" ? var.ssd_data_disk_storage : var.storage
  # BPG provider expects disk size in GB (number)
  disk_size_gb        = tonumber(replace(var.disk_size, "G", ""))
  ssd_data_disk_size_gb = tonumber(replace(var.ssd_data_disk_size, "G", ""))
}

resource "proxmox_virtual_environment_vm" "vm" {
  name     = var.name
  node_name = var.target_node
  vm_id    = var.vmid != 0 ? var.vmid : null # null = auto-assign

  # Avoid in-place updates touching ide2 (cloud-init CDROM); Proxmox rejects "unable to change media type".
  # To change SSH keys, ip_config, or cloudinit_username, destroy and recreate the VM or temporarily remove this block.
  lifecycle {
    ignore_changes = [initialization]
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
    floating  = var.memory_floating != null ? var.memory_floating : var.memory
  }

  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = local.disk_size_gb
  }

  dynamic "disk" {
    for_each = var.enable_ssd_data_disk ? [1] : []
    content {
      datastore_id = local.ssd_data_disk_storage
      interface    = "scsi1"
      size         = local.ssd_data_disk_size_gb
    }
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = trimspace(var.cloudinit_cdrom_storage) != "" ? var.cloudinit_cdrom_storage : var.storage
    ip_config {
      ipv4 {
        address = var.ip_config == "ip=dhcp" ? "dhcp" : trimspace(split(",", replace(var.ip_config, "ip=", ""))[0])
        gateway = var.ip_config != "ip=dhcp" ? var.gateway : null
      }
    }
    user_account {
      keys     = [var.ssh_public_key]
      username = var.cloudinit_username
    }
  }

  operating_system {
    type = "l26"
  }

  boot_order = ["scsi0"]
}
