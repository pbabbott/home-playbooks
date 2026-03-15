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
  description = "Name of the cloud-init template to clone from (template is created by playbooks/proxmox/create-ubuntu-template.yml)"
  type        = string
  default     = "tf-template-ubuntu-noble"
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

variable "enable_nonprod_worker_ssd_data_disk" {
  description = "If true, non-prod worker VMs (name contains \"-worker-\") get an additional SSD data disk."
  type        = bool
  default     = true
}

variable "nonprod_worker_ssd_data_disk_size" {
  description = "Size for the additional SSD data disk on non-prod worker VMs."
  type        = string
  default     = "256G"

  validation {
    condition     = trimspace(var.nonprod_worker_ssd_data_disk_size) != ""
    error_message = "nonprod_worker_ssd_data_disk_size must be a non-empty size string."
  }
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file used by cloud-init for cloned VMs"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
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

# Non-prod static IPs (192.168.6.0/22). One entry per non-prod VM; keys must match nonprod_vms.
variable "nonprod_static_ips" {
  description = "Static IP address per non-prod VM (keys must match nonprod_vms). Used with /22 and nonprod_gateway."
  type        = map(string)
  default = {
    "tf-nonprod-k8s-controller-1" = "192.168.6.31"
    "tf-nonprod-k8s-worker-1"     = "192.168.6.32"
    "tf-nonprod-k8s-worker-2"     = "192.168.6.33"
    "tf-nonprod-k8s-worker-3"     = "192.168.6.34"
  }
}

variable "nonprod_gateway" {
  description = "Default gateway for non-prod VMs"
  type        = string
  default     = "192.168.4.1"
}

