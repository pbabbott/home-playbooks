# gen3 k3s nodes on chimaera (joining the hogwarts cluster). Cloned from template 911 (tpl-k3s-noble, built by
# scripts/build-k3s-template.sh chimaera). 900/901 on this host are the legacy gen2 templates: do not use them here.
# Controller (etcd) root on local-lvm = the SATA SSD that also holds the host OS (accepted; it stalled etcd on gen2, so keep the
# ALPM udev rule: playbooks/proxmox-chimaera/disable-ssd-power-mgmt.yml). Worker root + Longhorn disk on nvme-fast (NVMe).

module "base_template" {
  source = "../modules/ubuntu-template"

  node_name       = var.proxmox_node
  vm_id           = 910
  use_import      = true # PVE 9.x has the `import` content type (the old 8.2.4 host did not)
  ssh_public_keys = [trimspace(file("~/.ssh/id_ed25519.pub"))]
}

module "k3s_vm" {
  for_each = var.k3s_vms
  source   = "../modules/vm"

  vmid         = each.value.vmid
  name         = each.key
  target_node  = var.proxmox_node
  ip_address   = each.value.ip
  template_id  = 911
  cores        = each.value.cores
  memory       = each.value.memory
  datastore_id = each.value.datastore_id
  data_disks   = each.value.data_disk_gb == null ? [] : [{ size = each.value.data_disk_gb, datastore_id = each.value.datastore_id }]

  dns_servers     = ["192.168.4.144", "1.1.1.1"]
  ssh_public_keys = [trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))]
}
