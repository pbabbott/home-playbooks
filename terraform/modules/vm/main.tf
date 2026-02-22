resource "proxmox_vm_qemu" "vm" {
  vmid        = var.vmid
  name        = var.name
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true

  cores   = var.cores
  memory  = var.memory
  os_type = "cloud-init"

  disk {
    size    = var.disk_size
    type    = "scsi"
    storage = var.storage
  }

  network {
    model  = "virtio"
    bridge = var.bridge
  }

  # Cloud-init
  cloudinit_cdrom_storage = coalesce(var.cloudinit_cdrom_storage, var.storage)
  ipconfig0               = var.ip_config
  sshkeys                 = var.ssh_public_key

  # Boot from disk
  boot = "order=scsi0"

  # Optional: allow agent to report IP (requires qemu-guest-agent in template)
  agent = 1
}
