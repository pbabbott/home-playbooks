variable "name" {
  description = "VM name (used as hostname)"
  type        = string
}

variable "vmid" {
  description = "Proxmox VM ID. Use 0 to auto-assign. Convention: 200=production, 300=non-prod, 500=dev workstations."
  type        = number
  default     = 0
}

variable "target_node" {
  description = "Proxmox node to create the VM on"
  type        = string
}

variable "template_name" {
  description = "Name of the cloud-init template to clone from"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Boot disk size (e.g. 20G)"
  type        = string
  default     = "20G"
}

variable "storage" {
  description = "Storage name for the disk"
  type        = string
}

variable "bridge" {
  description = "Bridge for the network interface"
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_key" {
  description = "SSH public key content for cloud-init"
  type        = string
}

variable "ip_config" {
  description = "Cloud-init ipconfig string (e.g. ip=dhcp or ip=192.168.1.10/24,gw=192.168.1.1)"
  type        = string
  default     = "ip=dhcp"
}

variable "cloudinit_cdrom_storage" {
  description = "Storage for cloud-init CDROM (defaults to same as disk storage)"
  type        = string
  default     = null
}
