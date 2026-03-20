# BPG Proxmox provider: https://github.com/bpg/terraform-provider-proxmox
# If you see "501 no such file '/json/access/users'" on plan, see docs/proxmox-api-token.md.
# Endpoint must be base URL (e.g. https://pve.example.com:8006/); /api2/json is stripped if present.
provider "proxmox" {
  endpoint  = "${trim(replace(var.proxmox_api_url, "/api2/json", ""), "/")}/"
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}
