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

variable "template_id" {
  description = "Proxmox VM ID of the cloud-init template to clone from (resolved from template name in root module)"
  type        = number
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU model type for Proxmox (for example kvm64, x86-64-v2-AES, host)"
  type        = string
  default     = "kvm64"
}

variable "memory" {
  description = "Dedicated (maximum) memory in MB"
  type        = number
  default     = 2048
}

variable "memory_floating" {
  description = "Floating (minimum) memory in MB."
  type        = number
  default     = null
}

variable "disk_size" {
  description = "Boot disk size (e.g. 32G)"
  type        = string
  default     = "32G"
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
  description = "Storage target for the optional SSD data disk (for example longhorn-ssd). Empty string falls back to main storage."
  type        = string
  default     = ""

  validation {
    condition     = trimspace(var.ssd_data_disk_storage) == "" || length(trimspace(var.ssd_data_disk_storage)) > 0
    error_message = "ssd_data_disk_storage must be a non-empty storage name when set."
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

variable "cloudinit_username" {
  description = "Username for cloud-init user account (must exist in the template, e.g. ubuntu for create-ubuntu-template)"
  type        = string
  default     = "ubuntu"
}

variable "ip_config" {
  description = "Cloud-init ipconfig string (e.g. ip=dhcp or ip=192.168.1.10/24,gw=192.168.1.1)"
  type        = string
  default     = "ip=dhcp"
}

variable "cloudinit_cdrom_storage" {
  description = "Storage for cloud-init CDROM (defaults to same as disk storage). Empty string uses disk storage."
  type        = string
  default     = ""
}
