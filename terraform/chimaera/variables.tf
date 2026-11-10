########################################################
# Proxmox API credentials
variable "proxmox_api_url" {
  description = "Proxmox API base URL (e.g. https://192.168.4.192:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g. user@pam!terraform)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

########################################################
# Proxmox node

variable "proxmox_node" {
  description = "Default Proxmox node name for VMs"
  type        = string
  default     = "chimaera"
}

########################################################
# gen3 k3s nodes

variable "k3s_vms" {
  description = "gen3 k3s nodes on chimaera (cloned from template 911). memory in MB, datastore_id = storage for the root disk, cloud-init and the data disk (controller on local-lvm = SATA SSD with the OS; worker on nvme-fast = NVMe). data_disk_gb optional (Longhorn disk)."
  type = map(object({
    vmid         = number
    ip           = string
    cores        = number
    memory       = number
    datastore_id = string
    data_disk_gb = optional(number)
  }))
  default = {
    "tf-prod-k3s-controller-3" = { vmid = 215, ip = "192.168.6.45", cores = 2, memory = 4096, datastore_id = "local-lvm" }
    "tf-prod-k3s-worker-3"     = { vmid = 216, ip = "192.168.6.46", cores = 8, memory = 32768, datastore_id = "nvme-fast", data_disk_gb = 100 }
  }
}
