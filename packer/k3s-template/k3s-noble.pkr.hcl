packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1.2"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1.1"
    }
  }
}

source "proxmox-clone" "k3s" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  clone_vm_id = var.base_template_id
  full_clone  = true
  vm_id       = var.template_id
  vm_name     = var.template_name

  template_name        = var.template_name
  template_description = "k3s-ready Ubuntu 24.04 (built by packer/k3s-template)"

  tags                    = "template;ubuntu-noble;k3s"
  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool
  scsi_controller         = "virtio-scsi-single"
  cores                   = 4
  cpu_type                = "host"
  os                      = "l26"
  memory                  = 4096

  network_adapters {
    bridge = var.bridge
    model  = "virtio"
  }

  # Build VM has no DHCP expectation; use a temporary static address. Final VMs get their own IP from Terraform.
  ipconfig {
    ip      = "${var.build_ip}/22"
    gateway = var.gateway
  }
  nameserver = "192.168.4.144 1.1.1.1"

  ssh_host             = var.build_ip
  ssh_username         = "firebolt"
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = var.ssh_timeout
}

build {
  sources = ["source.proxmox-clone.k3s"]

  provisioner "ansible" {
    playbook_file = "${path.root}/../../playbooks/k3s-template/main.yml"
    user          = "firebolt"
    use_proxy     = false
    extra_arguments = [
      "--ssh-extra-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null",
      "-e", "ansible_python_interpreter=/usr/bin/python3",
    ]
  }
}
