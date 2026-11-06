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
# VM Fleets (gen3) — none defined yet
