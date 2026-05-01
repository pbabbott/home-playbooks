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
# VM Fleets

variable "nonprod_vms" {
  type = map(object({
    vmid   = number
    ip     = string
    memory = number
  }))
  default = {
    "tf-nonprod-k8s-controller-1" = {
      vmid   = 301
      ip     = "192.168.6.31"
      memory = 2560
    }
    "tf-nonprod-k8s-worker-1" = {
      vmid   = 302
      ip     = "192.168.6.32"
      memory = 3584
    }
    "tf-nonprod-k8s-worker-2" = {
      vmid   = 303
      ip     = "192.168.6.33"
      memory = 3584
    }
    "tf-nonprod-k8s-worker-3" = {
      vmid   = 304
      ip     = "192.168.6.34"
      memory = 3584
    }
  }
}

variable "prod_vms" {
  type = map(object({
    vmid   = number
    ip     = string
    memory = number
  }))
  default = {
    "tf-prod-k8s-controller-1" = {
      vmid   = 204
      ip     = "192.168.6.24"
      memory = 2560
    }
    "tf-prod-k8s-worker-1" = {
      vmid   = 205
      ip     = "192.168.6.25"
      memory = 4096
    }
    "tf-prod-k8s-worker-2" = {
      vmid   = 206
      ip     = "192.168.6.26"
      memory = 4096
    }
    "tf-prod-k8s-worker-3" = {
      vmid   = 207
      ip     = "192.168.6.27"
      memory = 4096
    }
  }
}
