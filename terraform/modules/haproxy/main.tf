# Nesting helps systemd (e.g. systemd-networkd) in LXC. Proxmox only allows API changes to LXC feature flags
# on privileged CTs when the API identity is root@pam — other tokens get HTTP 403. Do not set `features`
# in Terraform unless your provider uses a root@pam token; enable CT Options → Features → Nesting in the UI
# once, or: `pct set <vmid> -features nesting=1` on the node.
locals {
  haproxy_ipv4_cidr    = "192.168.6.28/22"
  haproxy_ipv4_address = "192.168.6.28"
  haproxy_gateway      = "192.168.4.1"

  # Shared SSH target for provisioners (LXC guest, not the Proxmox node).
  ssh_haproxy = {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = local.haproxy_ipv4_address
    timeout     = "2m"
  }
}

# 1. Download the Ubuntu 24.04 standard template
resource "proxmox_virtual_environment_download_file" "ubuntu_noble_template" {
  node_name    = "chimaera"
  content_type = "vztmpl" # This tells Proxmox it's an LXC template
  datastore_id = "local"  # This is where it will be stored

  # Proxmox publishes 24.04-2; the older 24.04-1 artifact was removed (404).
  url = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"

  checksum           = "75a827c4ea4b2bef42e0521f51ed869e398f56b0e6b131c3cd5d284a2e0e08b5"
  checksum_algorithm = "sha256"
}

# 2. Spin up the LXC Container
resource "proxmox_virtual_environment_container" "haproxy_lxc" {
  depends_on = [proxmox_virtual_environment_download_file.ubuntu_noble_template]

  node_name = "chimaera"
  vm_id     = 208

  unprivileged = false

  initialization {
    hostname = "tf-haproxy-lb"

    ip_config {
      ipv4 {
        address = local.haproxy_ipv4_cidr
        gateway = local.haproxy_gateway
      }
      # Proxmox LXC: ip6=manual — no SLAAC/DHCPv6 from the hypervisor (see wiki Linux_Container net ip6=)
      ipv6 {
        address = "manual"
      }
    }

    user_account {
      keys = [file(pathexpand("~/.ssh/id_ed25519.pub"))]
    }
  }

  wait_for_ip {
    ipv4 = true
    ipv6 = false
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = false
  }

  operating_system {
    # Format is "datastore:type/template_name"
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    type             = "ubuntu"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }
}

# Guest-only setup: install package + deploy config + reload. Re-runs when the CT is replaced or haproxy.cfg changes.
resource "terraform_data" "haproxy_guest" {
  depends_on = [proxmox_virtual_environment_container.haproxy_lxc]

  triggers_replace = [
    proxmox_virtual_environment_container.haproxy_lxc.id,
    filemd5("${path.module}/haproxy.cfg"),
  ]

  # 1) Package, LXC-safe systemd drop-in for the stock unit, enable unit (config not valid until step 3).
  provisioner "remote-exec" {
    inline = [
      "set -eux",
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get update",
      "apt-get install -y haproxy",
      "mkdir -p /etc/systemd/system/haproxy.service.d",
      "printf '%s\\n' '[Service]' 'BindReadOnlyPaths=' > /etc/systemd/system/haproxy.service.d/lxc-no-bind.conf",
      "systemctl daemon-reload",
      "systemctl enable haproxy",
    ]
    connection {
      type        = local.ssh_haproxy.type
      user        = local.ssh_haproxy.user
      private_key = local.ssh_haproxy.private_key
      host        = local.ssh_haproxy.host
      timeout     = local.ssh_haproxy.timeout
    }
  }

  # 2) Upload repo config (same path as file() in triggers_replace).
  provisioner "file" {
    source      = "${path.module}/haproxy.cfg"
    destination = "/tmp/haproxy.cfg.tf"
    connection {
      type        = local.ssh_haproxy.type
      user        = local.ssh_haproxy.user
      private_key = local.ssh_haproxy.private_key
      host        = local.ssh_haproxy.host
      timeout     = local.ssh_haproxy.timeout
    }
  }

  # 3) Install config, check syntax, restart (first start uses real cfg).
  provisioner "remote-exec" {
    inline = [
      "set -eux",
      "install -m 0644 -o haproxy -g haproxy /tmp/haproxy.cfg.tf /etc/haproxy/haproxy.cfg",
      "rm -f /tmp/haproxy.cfg.tf",
      "haproxy -c -f /etc/haproxy/haproxy.cfg",
      "systemctl restart haproxy",
      "systemctl is-active haproxy",
    ]
    connection {
      type        = local.ssh_haproxy.type
      user        = local.ssh_haproxy.user
      private_key = local.ssh_haproxy.private_key
      host        = local.ssh_haproxy.host
      timeout     = local.ssh_haproxy.timeout
    }
  }
}

