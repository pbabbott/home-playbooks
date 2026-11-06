## Layout

- Separate roots with separate state: `chimaera/` (gen2 + HAProxy), `hogwarts/` (gen3, no VMs yet), `cloudflare/`. Shared code is in `modules/`.
- Run terraform from inside a root, never from `terraform/` itself.

## Cloudflare

- DNS is managed by `external-dns` — do NOT add DNS record resources to Terraform.
- When adding new Cloudflare resources that require additional API token permissions, update `docs/cloudflare-api-token.md` to reflect the new required permissions.
