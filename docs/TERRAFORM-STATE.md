# Terraform state backend

State for `terraform/hogwarts/` is stored in Postgres on the NAS (`room_of_requirement`, `nas.local.abbottland.io:5432`,
no SSL, LAN only), using the Terraform `pg` backend. One database, one schema per root (`hogwarts`; `chimaera` and
`cloudflare` still use local state). Locking uses Postgres advisory locks.

## One-time setup (manual)
Connect as `postgres` (admin password is in the 1Password item `harbor-db-secret`) and run:

```sql
CREATE ROLE terraform LOGIN PASSWORD '<password>';
CREATE DATABASE terraform_state OWNER terraform;
REVOKE ALL ON DATABASE terraform_state FROM PUBLIC;
```

Then create a 1Password Login item `terraform-state-db` in the `Homelab` vault with username `terraform` and that password.
(The Connect token is read-only, so items can't be created by script.)

## Use
```sh
cd terraform/hogwarts
source ../../scripts/tfstate-env.sh   # exports PG_CONN_STR from the 1Password item
terraform init                        # first time on a root with existing local state: terraform init -migrate-state
```

The `terraform` role can only reach `terraform_state`; no other app databases. Back up this database with the NAS Postgres backups.

## Gotcha: always init as the `terraform` role
The backend creates its schema, `states` table and the shared sequence `public.global_states_id_seq` on first init. If that
first init is run as `postgres` (e.g. wrong username in the 1Password item), those objects are owned by `postgres` and the
`terraform` role gets "permission denied" (reads work, state *writes* fail at the end of an apply). Fix as `postgres`, in `terraform_state`:

```sql
ALTER SCHEMA <schema> OWNER TO terraform;
ALTER TABLE <schema>.states OWNER TO terraform;
ALTER SEQUENCE public.global_states_id_seq OWNER TO terraform;
```
Check who you are connected as: `echo $PG_CONN_STR | sed -E 's#^postgres://([^:]+):.*#\1#'` (should print `terraform`).

## Recover / inspect
State is in `<schema>.states` (column `data`). `terraform state pull > backup.tfstate` takes a copy.
