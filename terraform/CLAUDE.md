## Layout

- Separate roots with separate state: `chimaera/` (gen2 + HAProxy), `hogwarts/` (gen3: base template 900 only, no fleet yet), `cloudflare/`. Shared code is in `modules/`.
- Run terraform from inside a root, never from `terraform/` itself.
- State: `hogwarts/` uses the `pg` backend (NAS Postgres, db `terraform_state`, schema `hogwarts`). Run `source ../../scripts/tfstate-env.sh` first (sets `PG_CONN_STR` from 1Password). `chimaera/` and `cloudflare/` still use local state.

## Cloudflare

- DNS is managed by `external-dns` — do NOT add DNS record resources to Terraform.
- When adding new Cloudflare resources that require additional API token permissions, update `docs/cloudflare-api-token.md` to reflect the new required permissions.
