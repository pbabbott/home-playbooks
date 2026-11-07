# Base VM template 900 (stock Ubuntu 24.04 cloud image + cloud-init). Never booted.
# Prereq (token lacks Sys.Modify for URL downloads), once per host / image refresh:
#   ssh root@192.168.4.196 "wget -O /var/lib/vz/import/noble-server-cloudimg-amd64.qcow2 \
#     https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
# Layer 2 (901, tpl-k3s-noble) is built from this by packer/k3s-template.

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
