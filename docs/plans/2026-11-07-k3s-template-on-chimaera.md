# Plan: build the k3s node template on chimaera too

Status: **idea, not started.** Delete this file once it is implemented (the result should be documented in
`packer/k3s-template/README.md` and `playbooks/k3s-template/README.md`).

## Why
The gen3 k3s cluster is meant to have one controller on `chimaera` and one on `hogwarts` (third is `dumbledore`, offline) for
etcd quorum (`docs/HOSTS.md`). A chimaera controller needs a template on chimaera: Proxmox templates are per host and clones are
local. The template work so far (hogwarts only) was written to be reusable, but some things are hardcoded.

## Feasible as is
- `playbooks/k3s-template/main.yml` runs on the VM, not on Proxmox, so it works unchanged.
- State backend: a `chimaera` schema already exists (`docs/TERRAFORM-STATE.md`).
- VM module (`terraform/modules/vm`) already takes the node, template ID and SSH keys.

## What to change
| Area | Today | For chimaera |
|---|---|---|
| VM IDs | base `900`, k3s `901` | **`901` is the gen2 template on chimaera.** Use other IDs (e.g. `910` base, `911` k3s). Packer already has `base_template_id` / `template_id` variables. |
| Packer | defaults point at hogwarts (`proxmox_node`, API URL, token) | override for chimaera; add `scripts/packer-env-chimaera.sh` (chimaera token from 1Password, user is `user@pam!terraform`); build IP from the static `192.168.6.x` space (reserve it in `docs/NETWORK.md`) |
| Base template (VM 900) | `terraform/hogwarts/templates.tf`, node/ID/image inline | move into a shared module (e.g. `terraform/modules/ubuntu-template`: node, vm_id, datastore, image url + checksum) and call it from both roots. Copying the file into the chimaera root is the quick alternative. |
| Image download | works on hogwarts because `terraform@pve` has the custom role `TerraformSysModify` (`terraform/README.md`) | chimaera's API user needs the same privilege (`pveum role add ... --privs Sys.Modify` + `pveum acl modify /`), or download the image by hand |
| Scripts | `scripts/verify-k3s-template.sh` and `build-k3s-template.sh` hardcode `192.168.4.196` and test VM IDs 9998/9999 | take the Proxmox host and IDs as arguments/env |
| Docs | hogwarts only | note both hosts; update `docs/HOSTS.md` template IDs |

## Check before starting
- **Proxmox version on chimaera.** The `import` content type / `import_from` need Proxmox 8.2+. Not recorded in `docs/HOSTS.md`.
- **Storage.** `local-lvm` exists (gen2 used it). `fast-ssd` and `etcd-ssd` are chimaera-only pools and are not needed for the template,
  but k3s VMs may want etcd on `etcd-ssd` (see `proxmox-chimaera/` and `docs/plans/2026-05-2*-*etcd*.md`).
- **Capacity.** Chimaera is described as maxed out; the template itself only costs disk, but k3s VMs would compete with gen2.
- **Bridge name** is assumed `vmbr0` (true for the gen2 module); confirm.

## Order of work
1. Confirm Proxmox version, bridge and token privileges on chimaera.
2. Extract the base-template Terraform into a module; point hogwarts at it (plan must show no changes), then add it to the chimaera root (additions only).
3. Parameterize the Packer vars and scripts for the host; add the chimaera env script.
4. Build and run `verify-k3s-template.sh` against chimaera.
5. Update docs, delete this file.
