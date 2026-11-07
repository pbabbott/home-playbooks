resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vmid != 0 ? var.vmid : null # null = auto-assign
  started   = var.started

  # The root disk comes from the template clone; ignore `disk` or Terraform would try to reconcile it away. This also means
  # data_disks are create-time only (resizing/adding later is done by hand or by recreating the VM).
  # cloud-init (`initialization`) is managed, so changing ip / user / keys is a normal in-place update.
  lifecycle {
    ignore_changes = [disk]
  }

  clone {
    vm_id = var.template_id
    full  = true
    # null = same datastore as the template. Set to place the cloned root disk on another pool.
    datastore_id = var.datastore_id
  }

  # Extra data disks (scsi1..), on the same pool as the root disk when datastore_id is set.
  dynamic "disk" {
    for_each = var.data_disks
    content {
      datastore_id = coalesce(disk.value.datastore_id, var.datastore_id)
      interface    = "scsi${disk.key + 1}"
      size         = disk.value.size
      iothread     = true
      discard      = "on"
      ssd          = true
      file_format  = "raw"
    }
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
    # Cloud-init drive pool. null = provider default.
    datastore_id = var.datastore_id

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }

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
