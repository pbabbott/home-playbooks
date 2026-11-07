variable "proxmox_api_url" {
  type        = string
  description = "e.g. https://192.168.4.196:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "hogwarts"
}

variable "base_template_id" {
  type    = number
  default = 900
}

variable "template_id" {
  type    = number
  default = 901
}

variable "template_name" {
  type    = string
  default = "tpl-k3s-noble"
}

variable "build_ip" {
  type        = string
  description = "Free IPv4 on 192.168.4.0/22 (192.168.6.x is the VM range) used only while building (not a DHCP-leased address)"
  default     = "192.168.6.250"
}

variable "gateway" {
  type    = string
  default = "192.168.4.1"
}

variable "ssh_private_key_file" {
  type    = string
  default = "~/.ssh/id_ed25519"
}

variable "ssh_timeout" {
  type    = string
  default = "10m"
}

variable "cloud_init_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Proxmox pool for the cloud-init drive of the build VM/template"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}
