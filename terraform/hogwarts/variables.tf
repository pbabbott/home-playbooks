########################################################
# Proxmox API credentials
variable "proxmox_api_url" {
  description = "Proxmox API base URL (e.g. https://192.168.4.196:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g. terraform@pve!terraform)"
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
  description = "Proxmox node name (check with `pvesh get /nodes` on the host)"
  type        = string
  default     = "hogwarts"
}

########################################################
# VM Fleets (gen3)

variable "prod_vms" {
  description = "gen3 prod k3s VMs (cloned from template 901), keyed by VM name. memory in MB, data_disk_gb optional (Longhorn disk)."
  type = map(object({
    vmid         = number
    ip           = string
    cores        = number
    memory       = number
    datastore_id = string
    data_disk_gb = optional(number)
  }))
  default = {
    "tf-prod-k3s-controller-1" = { vmid = 210, ip = "192.168.6.41", cores = 4, memory = 8192, datastore_id = "local-lvm" }
    "tf-prod-k3s-worker-1"     = { vmid = 211, ip = "192.168.6.42", cores = 6, memory = 16384, datastore_id = "vm-nvme-01", data_disk_gb = 100 }
    "tf-prod-k3s-worker-2"     = { vmid = 212, ip = "192.168.6.43", cores = 6, memory = 16384, datastore_id = "vm-nvme-02", data_disk_gb = 100 }
  }
}
