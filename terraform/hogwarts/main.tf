# gen3 k3s fleet on hogwarts: clones template 901 (tpl-k3s-noble) via the shared VM module.
# Identity (user + key) is injected via cloud-init; the template carries none.

module "prod_vm" {
  for_each = var.prod_vms
  source   = "../modules/vm"

  vmid         = each.value.vmid
  name         = each.key
  target_node  = var.proxmox_node
  ip_address   = each.value.ip
  template_id  = 901
  cores        = each.value.cores
  memory       = each.value.memory
  datastore_id = each.value.datastore_id
  data_disks   = each.value.data_disk_gb == null ? [] : [{ size = each.value.data_disk_gb }]

  dns_servers     = ["192.168.4.144", "1.1.1.1"]
  ssh_public_keys = [trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))]
}

# gen3 ingress LXC (replaces the gen2 HAProxy on chimaera, VM 208 / 192.168.6.28). Cutover = repoint the eero 80/443
# port-forward to this IP, then retire the old one.
module "haproxy" {
  source = "../modules/haproxy"

  node_name   = var.proxmox_node
  vmid        = 213
  hostname    = "tf-haproxy-gen3"
  ip_address  = "192.168.6.29"
  config_file = "${path.module}/haproxy.cfg"
}
