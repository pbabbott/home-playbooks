# Defaults reproduce the original gen2 LXC on chimaera (VM 208, 192.168.6.28).
variable "node_name" {
  description = "Proxmox node to run the LXC on"
  type        = string
  default     = "chimaera"
}

variable "vmid" {
  description = "Container ID"
  type        = number
  default     = 208
}

variable "hostname" {
  description = "Container hostname"
  type        = string
  default     = "tf-haproxy-lb"
}

variable "ip_address" {
  description = "Static IPv4 address (/22 is added)"
  type        = string
  default     = "192.168.6.28"
}

variable "gateway" {
  description = "Default gateway"
  type        = string
  default     = "192.168.4.1"
}

variable "datastore_id" {
  description = "Datastore for the container root disk"
  type        = string
  default     = "local-lvm"
}

variable "config_file" {
  description = "Path to the haproxy.cfg to deploy. null = the module's gen2 haproxy.cfg."
  type        = string
  default     = null
}
