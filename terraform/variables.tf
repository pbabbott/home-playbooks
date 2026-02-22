variable "proxmox_api_url" {
  description = "Proxmox API base URL (e.g. https://pve.example.com:8006/api2/json)"
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

variable "proxmox_node" {
  description = "Default Proxmox node name for VMs"
  type        = string
}

variable "template_name" {
  description = "Name of the cloud-init template to clone from"
  type        = string
}

variable "storage" {
  description = "Default storage for VM disks (e.g. local-lvm)"
  type        = string
}

variable "storage_ssd" {
  description = "Onboard SSD storage for VMs that need faster disk (e.g. longhorn-ssd). Pass to module as storage when desired."
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file for cloud-init"
  type        = string
}

variable "bridge" {
  description = "Bridge name for VM networking"
  type        = string
  default     = "vmbr0"
}

# Non-prod fleet (300 range): k8s controller + workers. Map of VM name -> VMID.
# Use tf-nonprod-* naming so these don't collide with production (e.g. k8s-controller-1 in 200 range).
variable "nonprod_vms" {
  description = "Non-prod VMs: map of name -> vmid (301 = controller, 302-304 = workers). Use tf-nonprod-* names."
  type        = map(number)
  default = {
    "tf-nonprod-k8s-controller-1" = 301
    "tf-nonprod-k8s-worker-1"     = 302
    "tf-nonprod-k8s-worker-2"     = 303
    "tf-nonprod-k8s-worker-3"     = 304
  }
}
