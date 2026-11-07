# k3s-template

Ansible provisioning for the gen3 k3s node template (`901`, `tpl-k3s-noble`) on `hogwarts`. Run by Packer
(`packer/k3s-template/`), which clones base template `900` (created by `terraform/hogwarts/templates.tf`).

Installs guest agent, `nfs-common`, `open-iscsi`; sets America/Chicago; disables IPv6 (kernel cmdline);
sets k3s prerequisites (modules, sysctls, no swap); cleans cloud-init, machine-id and SSH host keys. k3s itself is not installed.

Build: see [`packer/k3s-template/README.md`](../../packer/k3s-template/README.md).

Only `hogwarts` has this template so far. Plan for also building it on `chimaera` (temporary doc, delete once done):
[`docs/plans/2026-11-07-k3s-template-on-chimaera.md`](../../docs/plans/2026-11-07-k3s-template-on-chimaera.md).

## Required variables
None. `host_tz` defaults to `America/Chicago` (see `main.yml`). Packer supplies the SSH connection.
