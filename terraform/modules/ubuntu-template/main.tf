# Base VM template (stock Ubuntu 24.04 cloud image + cloud-init). Never booted. Layer 2 (tpl-k3s-noble) is built from it by
# packer/k3s-template. The image is pinned to a release and verified by checksum.
# To update: pick a newer dir at https://cloud-images.ubuntu.com/releases/noble/, update image_url + image_checksum, apply, rebuild.

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  image_file_name = var.use_import ? "noble-server-cloudimg-amd64.qcow2" : "noble-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_download_file" "image" {
  content_type       = var.use_import ? "import" : "iso"
  datastore_id       = var.image_datastore_id
  node_name          = var.node_name
  url                = var.image_url
  file_name          = local.image_file_name
  checksum           = var.image_checksum
  checksum_algorithm = "sha256"
}

resource "proxmox_virtual_environment_vm" "base" {
  name          = "tpl-ubuntu-noble-base"
  node_name     = var.node_name
  vm_id         = var.vm_id
  template      = true
  started       = false
  on_boot       = false # templates never start
  tags          = ["template", "ubuntu-noble"]
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]
  depends_on    = [proxmox_virtual_environment_download_file.image]

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  # No ballooning: k3s/etcd nodes want fixed memory.
  memory {
    dedicated = 4096
    floating  = 0
  }

  disk {
    datastore_id = var.datastore_id
    # Newer Proxmox (the `import` content type; absent on 8.2.4) supports `import` content (import_from); older hosts (chimaera 8.2.4) use an iso-content .img via file_id.
    import_from = var.use_import ? "${var.image_datastore_id}:import/${local.image_file_name}" : null
    file_id     = var.use_import ? null : proxmox_virtual_environment_download_file.image.id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = 60
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  serial_device {}

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore_id
    dns {
      servers = var.dns_servers
    }
    user_account {
      username = "firebolt"
      keys     = var.ssh_public_keys
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
