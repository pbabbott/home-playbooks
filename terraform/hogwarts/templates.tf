# Base VM template 900 (stock Ubuntu 24.04 cloud image + cloud-init). Never booted.
# The image is pinned to an Ubuntu release and verified by checksum. To update: pick a newer dir at
# https://cloud-images.ubuntu.com/releases/noble/, update the url + checksum (from its SHA256SUMS), apply, rebuild 901.
# Layer 2 (901, tpl-k3s-noble) is built from this by packer/k3s-template.

resource "proxmox_virtual_environment_download_file" "ubuntu_noble" {
  content_type       = "import"
  datastore_id       = "local"
  node_name          = var.proxmox_node
  url                = "https://cloud-images.ubuntu.com/releases/noble/release-20261017/ubuntu-24.04-server-cloudimg-amd64.img"
  file_name          = "noble-server-cloudimg-amd64.qcow2"
  checksum           = "04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94"
  checksum_algorithm = "sha256"
}

resource "proxmox_virtual_environment_vm" "tpl_ubuntu_noble_base" {
  name          = "tpl-ubuntu-noble-base"
  node_name     = var.proxmox_node
  vm_id         = 900
  template      = true
  started       = false
  on_boot       = false # templates never start
  tags          = ["template", "ubuntu-noble"]
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]
  depends_on    = [proxmox_virtual_environment_download_file.ubuntu_noble]

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
    datastore_id = "local-lvm"
    import_from  = "local:import/noble-server-cloudimg-amd64.qcow2"
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = 60
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  serial_device {}

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"
    dns {
      servers = ["192.168.4.144", "1.1.1.1"]
    }
    user_account {
      username = "firebolt"
      keys     = [trimspace(file("~/.ssh/id_ed25519.pub"))]
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
