## Layout

- Separate roots with separate state: `chimaera/` (gen3 k3s controller-3 + worker-3 in `k3s.tf`; gen2 and its HAProxy were removed 2026-11-10), `hogwarts/` (gen3: base template 900 only, no fleet yet), `cloudflare/`. Shared code is in `modules/`.
- Run terraform from inside a root, never from `terraform/` itself.
- State: every root uses the `pg` backend (NAS Postgres, db `terraform_state`, one schema per root: `hogwarts`, `chimaera`, `cloudflare`). Run `source ../../scripts/tfstate-env.sh` first (separate command, check it succeeded). Docs: `../docs/TERRAFORM-STATE.md`.

## Cloudflare

- DNS is managed by `external-dns` — do NOT add DNS record resources to Terraform.
- When adding new Cloudflare resources that require additional API token permissions, update `docs/cloudflare-api-token.md` to reflect the new required permissions.
