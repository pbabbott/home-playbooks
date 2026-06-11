## Cloudflare

- DNS is managed by `external-dns` — do NOT add DNS record resources to Terraform.
- When adding new Cloudflare resources that require additional API token permissions, update `docs/cloudflare-api-token.md` to reflect the new required permissions.
