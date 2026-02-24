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

variable "enable_ssd_data_disk" {
  description = "If true, attach an additional SSD-backed data disk on scsi1."
  type        = bool
  default     = false
}

variable "ssd_data_disk_storage" {
  description = "Storage target for the optional SSD data disk (for example longhorn-ssd). Null falls back to main storage."
  type        = string
  default     = null

  validation {
    condition     = var.ssd_data_disk_storage == null || trimspace(var.ssd_data_disk_storage) != ""
    error_message = "ssd_data_disk_storage must be null or a non-empty storage name."
  }
}

variable "ssd_data_disk_size" {
  description = "Size for the optional SSD data disk (for example 256G)."
  type        = string
  default     = "256G"

  validation {
    condition     = trimspace(var.ssd_data_disk_size) != ""
    error_message = "ssd_data_disk_size must be a non-empty size string."
  }
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
