variable "node_name" {
  type = string
}

variable "vm_id" {
  description = "Base template VM ID (hogwarts 900, chimaera 910; chimaera 900/901 are gen2 templates)"
  type        = number
}

variable "datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "image_datastore_id" {
  description = "File-based storage with the `import` content type enabled"
  type        = string
  default     = "local"
}

variable "image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/releases/noble/release-20261017/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "image_checksum" {
  type    = string
  default = "04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "dns_servers" {
  type    = list(string)
  default = ["192.168.4.144", "1.1.1.1"]
}

variable "ssh_public_keys" {
  type = list(string)
}

variable "use_import" {
  description = "Use the `import` content type (newer Proxmox). false = download to iso content and use file_id (chimaera, PVE 8.2.4)."
  type        = bool
  default     = true
}
