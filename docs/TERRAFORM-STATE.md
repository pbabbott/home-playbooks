# Terraform state backend

Where Terraform state lives, how to use it, and how to recover it.

## Summary

| Root | State location |
|---|---|
| `terraform/hogwarts/` | Postgres on the NAS (`pg` backend): db `terraform_state`, schema `hogwarts` |
| `terraform/chimaera/` | same database, schema `chimaera` (migrated from local file 2026-11-07, content verified identical) |
| `terraform/cloudflare/` | same database, schema `cloudflare` (no resources yet; state starts empty) |

- Server: `room_of_requirement` NAS, `nas.local.abbottland.io:5432` (Postgres 16, no SSL, LAN only).
- One database (`terraform_state`), one schema per root. Locking uses Postgres advisory locks.
- Dedicated role `terraform`, owner of `terraform_state` and nothing else. Its credentials are the 1Password item
  `terraform-state-db` (Homelab vault). The `postgres` admin (item `harbor-db-secret`) is only for one-time setup/repair.
- Connection string is never in git: `scripts/tfstate-env.sh` builds it into `PG_CONN_STR` from 1Password.

## Daily use
```sh
cd terraform/hogwarts
source ../../scripts/tfstate-env.sh     # sets PG_CONN_STR (prints a confirmation; check it did not error)
terraform init                          # first time on a machine
terraform plan
```
The hogwarts root also needs `terraform.tfvars` (`../../scripts/tfvars-node.sh`) for the Proxmox API token.
Run `source` and `terraform` as **separate** commands, not chained with `;`, so a failed lookup stops you
(otherwise Terraform runs with no backend connection).

## One-time setup (done; kept for rebuilds) — manual
There is no script on purpose: the Connect token is read-only and this is a one-off. As `postgres`:
```sql
CREATE ROLE terraform LOGIN PASSWORD '<password>';
CREATE DATABASE terraform_state OWNER terraform;
REVOKE ALL ON DATABASE terraform_state FROM PUBLIC;
```
Then create a Login item `terraform-state-db` in the `Homelab` vault: username `terraform`, the same password.
(No `psql` in the devcontainer: `docker run --rm -it postgres:17-alpine psql -h nas.local.abbottland.io -U postgres`.)

## Adding a new root (or migrating a local one)
Keep it simple: same database, same `terraform` role, **new schema per root**. No new roles or databases.
1. Add `backend.tf` to the root (copy `terraform/hogwarts/backend.tf`, change `schema_name`).
2. If the root has a local state, copy it somewhere safe first (`cp terraform.tfstate <backup dir>`).
3. `source ../../scripts/tfstate-env.sh` (check the user it prints is `terraform`), then `terraform init -migrate-state`.
4. Verify: `terraform state list` matches, `terraform plan` shows no changes. A migrated state gets a new serial/lineage; that is normal.
5. Update the table above.

The old local `terraform.tfstate` files (gitignored) are left empty after a migration; `terraform.tfstate.backup` keeps the last copy. Delete them once you are happy.

## Gotchas
- **Always init as the `terraform` role.** The backend creates its schema, `states` table and the shared sequence
  `public.global_states_id_seq` on first init. If that is run as `postgres` (e.g. wrong username in the 1Password item), they are
  owned by `postgres`: reads/plan work but state **writes fail at the end of an apply**. Check who you are:
  `sed -E 's#^postgres://([^:]+):.*#\1#' <<<"$PG_CONN_STR"` must print `terraform`. Repair as `postgres`, connected to `terraform_state`:
  ```sql
  ALTER SCHEMA <schema> OWNER TO terraform;
  ALTER TABLE <schema>.states OWNER TO terraform;
  ALTER SEQUENCE public.global_states_id_seq OWNER TO terraform;
  ```
- **Lost the `terraform` password?** As `postgres`: `ALTER ROLE terraform PASSWORD '<new>';` and put the same value in the 1Password item.
- **New 1Password items take a minute to appear** to Connect; `scripts/tfstate-env.sh` fails with "Found 0 item(s)" until they do.
- **Stuck lock** (a crashed run): `terraform force-unlock <id>` (the id is in the error message).

## Backup and recovery
- State is in `<schema>.states` (column `data`). Take an ad-hoc copy any time: `terraform state pull > backup.tfstate`.
- This database is the only copy of all state (hogwarts, chimaera, cloudflare). It should be covered by the NAS's Postgres backups (confirm this is configured).
- If the state is lost, VMs still exist in Proxmox; rebuild state with `terraform import` (e.g.
  `terraform import proxmox_virtual_environment_vm.tpl_ubuntu_noble_base hogwarts/900`).
