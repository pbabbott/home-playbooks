
variable "vmid" {
  description = "Proxmox VM ID. Use 0 to auto-assign. Convention: 200=production, 300=non-prod, 500=dev workstations."
  type        = number
}

variable "name" {
  description = "VM name (used as hostname)"
  type        = string
}

variable "ip_address" {
  description = "Cloud-init ip_address string: Simply 192.168.6.31, 192.168.6.32 etc. Subnet mask will be added automatically."
  type        = string
}
variable "template_id" {
  description = "Proxmox template ID"
  type        = number
}

variable "target_node" {
  description = "Proxmox node to create the VM on"
  type        = string
  default     = "chimaera"
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "cpu_type" {
  description = "Proxmox CPU model type (for example kvm64, x86-64-v2-AES, host)"
  type        = string
  default     = "host"
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "gateway" {
  description = "Default gateway for static IP (ignored when ip_config is ip=dhcp)"
  type        = string
  default     = "192.168.4.1"
}
