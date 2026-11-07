
variable "vmid" {
  description = "Proxmox VM ID. Use 0 to auto-assign. Convention: 200s=production, 300s=non-prod, 500s=dev workstations, 900s=templates."
  type        = number
}

variable "name" {
  description = "VM name (used as hostname)"
  type        = string
}

variable "ip_address" {
  description = "Static IPv4 address, e.g. 192.168.6.41. Subnet mask will be added automatically."
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

variable "started" {
  description = "Whether the VM should be running"
  type        = bool
  default     = true
}

variable "bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_keys" {
  description = "SSH public keys injected via cloud-init at create time. Required for the gen3 template (it has none baked in); leave empty for the gen2 template."
  type        = list(string)
  default     = []
}

variable "username" {
  description = "Cloud-init user (only used when ssh_public_keys is set)"
  type        = string
  default     = "firebolt"
}

variable "datastore_id" {
  description = "Proxmox datastore for the cloned root disk, extra data disks and the cloud-init drive. null = template's datastore (gen2 behaviour)."
  type        = string
  default     = null
}

variable "data_disks" {
  description = "Extra data disks (scsi1, scsi2, ...), create-time only. size in GB; datastore_id defaults to var.datastore_id."
  type = list(object({
    size         = number
    datastore_id = optional(string)
  }))
  default = []
}

variable "dns_servers" {
  description = "Cloud-init DNS servers. Empty = no dns block (template/DHCP default)."
  type        = list(string)
  default     = []
}
