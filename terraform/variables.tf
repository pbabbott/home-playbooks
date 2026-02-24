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

variable "ssh_public_key_path" {
  description = "Path to SSH public key file used by cloud-init for both template and cloned VMs"
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

# Ubuntu template build settings
variable "create_ubuntu_template" {
  description = "If true, Terraform manages the Ubuntu cloud-init template before VM clones (provider-native VM config plus minimal SSH helpers)."
  type        = bool
  default     = false
}

variable "ubuntu_template_name_prefix" {
  description = "Template naming prefix. Template names are built as <prefix>-<release>."
  type        = string
  default     = "tf-template-ubuntu"
}

variable "ubuntu_template_primary_release" {
  description = "Release key used as clone source when create_ubuntu_template=true (for example noble => tf-template-ubuntu-noble)."
  type        = string
  default     = "noble"

  validation {
    condition     = can(var.ubuntu_template_vmids[var.ubuntu_template_primary_release])
    error_message = "ubuntu_template_primary_release must exist as a key in ubuntu_template_vmids."
  }
}

variable "ubuntu_template_vmids" {
  description = "Map of Ubuntu release -> template VMID. Add more entries (for example jammy = 902) to manage multiple templates."
  type        = map(number)
  default = {
    noble = 901
  }

  validation {
    condition = alltrue([
      for vmid in values(var.ubuntu_template_vmids) : vmid > 0
    ])
    error_message = "All ubuntu_template_vmids values must be positive integers."
  }
}

variable "ubuntu_template_disk_resize" {
  description = "Optional disk resize value for scsi0 (for example +32G). Empty string skips resize."
  type        = string
  default     = "+32G"
}

variable "ubuntu_template_memory" {
  description = "Memory for the template VM in MB."
  type        = number
  default     = 6144

  validation {
    condition     = var.ubuntu_template_memory > 0
    error_message = "ubuntu_template_memory must be greater than 0."
  }
}

variable "ubuntu_template_cores" {
  description = "CPU cores for the template VM."
  type        = number
  default     = 4

  validation {
    condition     = var.ubuntu_template_cores > 0
    error_message = "ubuntu_template_cores must be greater than 0."
  }
}

variable "ubuntu_template_storage" {
  description = "Storage to use for template disk/cloud-init. Empty means fallback to var.storage."
  type        = string
  default     = ""
}

variable "ubuntu_template_bridge" {
  description = "Network bridge for template net0."
  type        = string
  default     = "vmbr0"
}

variable "ubuntu_template_ipconfig0" {
  description = "Cloud-init ipconfig0 for the template."
  type        = string
  default     = "ip=dhcp"
}

variable "ubuntu_template_ciuser" {
  description = "Optional cloud-init ciuser value for template defaults."
  type        = string
  default     = ""
}

variable "ubuntu_template_cipassword" {
  description = "Optional cloud-init cipassword for template defaults."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ubuntu_template_ssh_public_key_path_on_proxmox" {
  description = "Optional path to an SSH public key file that already exists on the Proxmox host. Used when local ssh_public_key_path is unavailable."
  type        = string
  default     = ""
}

variable "ubuntu_template_work_dir" {
  description = "Directory on the Proxmox host where cloud images and temporary ssh key files are stored."
  type        = string
  default     = "/var/lib/vz/template/cloud"
}

variable "ubuntu_template_proxmox_ssh_host" {
  description = "SSH host/IP for the Proxmox node. Empty means fallback to var.proxmox_node."
  type        = string
  default     = ""
}

variable "ubuntu_template_proxmox_ssh_user" {
  description = "SSH user used to run qm commands on the Proxmox host."
  type        = string
  default     = "root"
}

variable "ubuntu_template_proxmox_ssh_port" {
  description = "SSH port for the Proxmox host."
  type        = number
  default     = 22

  validation {
    condition     = var.ubuntu_template_proxmox_ssh_port > 0 && var.ubuntu_template_proxmox_ssh_port <= 65535
    error_message = "ubuntu_template_proxmox_ssh_port must be between 1 and 65535."
  }
}
