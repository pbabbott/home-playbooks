# BPG Proxmox provider: https://github.com/bpg/terraform-provider-proxmox
# Endpoint must be base URL (e.g. https://192.168.4.196:8006/); /api2/json is stripped if present.
provider "proxmox" {
  endpoint  = "${trim(replace(var.proxmox_api_url, "/api2/json", ""), "/")}/"
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true

  ssh {
    agent       = true # Set to false if you aren't using an SSH agent
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")

    # Map the Proxmox node name to its IP so Terraform can SSH to it
    node {
      name    = var.proxmox_node
      address = "192.168.4.196"
    }
  }
}
