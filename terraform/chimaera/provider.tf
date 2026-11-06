# BPG Proxmox provider: https://github.com/bpg/terraform-provider-proxmox
# If you see "501 no such file '/json/access/users'" on plan, see docs/proxmox-api-token.md.
# Endpoint must be base URL (e.g. https://pve.example.com:8006/); /api2/json is stripped if present.
provider "proxmox" {
  endpoint  = "${trim(replace(var.proxmox_api_url, "/api2/json", ""), "/")}/"
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true

  ssh {
    agent       = true # Set to false if you aren't using an SSH agent
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")

    # You must map your node name to its IP address so Terraform knows where to SSH
    node {
      name    = "chimaera"
      address = "192.168.4.192"
    }
  }
}
