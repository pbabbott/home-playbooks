variable "cloudflare_api_token" {
  description = "Cloudflare API token (needs Zone:Read, Zone Settings:Edit, Firewall Services:Edit)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for abbottland.io"
  type        = string
}

