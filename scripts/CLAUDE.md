# scripts/

Helpers for the Ansible / Terraform / Packer workflows. Run from the repo root (`./scripts/x.sh`);
scripts marked **source** must be sourced (`source scripts/x.sh`), not executed, because they export env vars.
Most need the `op` CLI (1Password, Homelab vault) and `jq`; the devcontainer provides both.

## Manifest

Every file in this dir has exactly one row here (enforced by `check-manifest.sh`, a pre-commit hook).

| Script | Use | What it does |
|---|---|---|
| `setup.sh` | run | Installs pinned Galaxy roles + collections from `requirements.yml` into `.ansible/`. |
| `vault-pass.sh` | run | Writes `vault_pass.txt` (gitignored) from 1Password item `ansible_vault_pass`; `--force` to overwrite. |
| `vault-protect.py` | pre-commit | Hook (`.pre-commit-config.yaml`): rejects a commit if `./vault.yml` is not encrypted. Not run by hand. |
| `tfstate-env.sh` | **source** | Exports `PG_CONN_STR` (NAS Postgres backend, 1Password item `terraform-state-db`). Required before terraform in any root; run as its own command. |
| `tfvars-node.sh` | run | Writes `terraform/<node>/terraform.tfvars` (Proxmox API token from 1Password). `NODE_ARG=hogwarts\|chimaera` (default hogwarts); `--force` to overwrite. |
| `node-env.sh` | **source** (library) | Defines `node_env <hogwarts\|chimaera>`: per-host IP, template IDs (hogwarts 900/901, chimaera 910/911), pool, TF root, 1Password item. Only place node settings live. Refuses chimaera 900/901 (legacy gen2). |
| `packer-env.sh` | **source** | Exports `PKR_VAR_*` for `packer/k3s-template/` for a node (`source scripts/packer-env.sh <node>`). |
| `build-k3s-template.sh` | run | End-to-end rebuild of the gen3 k3s template on a node: tfvars, base template via Terraform, Packer build, then `verify-k3s-template.sh`. `[hogwarts\|chimaera]`, default hogwarts. |
| `verify-k3s-template.sh` | run | Smoke test: clones the template twice (temp VMs 9998/9999, IPs `.251/.252`), checks node setup and uniqueness, destroys them. |
| `check-manifest.sh` | pre-commit | Fails if a file here has no row in this table, or a row names a missing file. |

## Common workflows

- **First-time setup:** `./scripts/setup.sh`, then `./scripts/vault-pass.sh`.
- **Terraform:** `source scripts/tfstate-env.sh`, then (if `terraform.tfvars` is missing) `NODE_ARG=<node> ./scripts/tfvars-node.sh`, then terraform from inside the root.
- **Rebuild a k3s template:** `./scripts/build-k3s-template.sh [hogwarts|chimaera]` (verifies at the end; re-run `verify-k3s-template.sh` alone to re-test).

## Keeping this current

When you add, rename, change the purpose of, or remove a script, in the same commit update: the manifest table above,
the workflow lists in `../CLAUDE.md` and `../README.md` if a workflow changed, and any doc that names the script.
Prefer one script per job; don't leave back-compat wrappers (delete and fix the docs instead; git history keeps them).
