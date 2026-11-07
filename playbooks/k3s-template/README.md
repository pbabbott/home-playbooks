# k3s-template

Ansible provisioning for the gen3 k3s node template (`901`, `tpl-k3s-noble`) on `hogwarts`. Run by Packer
(`packer/k3s-template/`), which clones base template `900` (created by `terraform/hogwarts/templates.tf`).

Installs guest agent, `nfs-common`, `open-iscsi`; sets America/Chicago; disables IPv6 (kernel cmdline);
sets k3s prerequisites (modules, sysctls, no swap); cleans cloud-init, machine-id and SSH host keys. k3s itself is not installed.

Build: see [`packer/k3s-template/README.md`](../../packer/k3s-template/README.md).

Built per Proxmox node: hogwarts (900/901) and chimaera (910/911, because 900/901 there are gen2). Per-node settings live in `scripts/node-env.sh`; run `scripts/build-k3s-template.sh <hogwarts|chimaera>`.

## Required variables
None. `host_tz` defaults to `America/Chicago` (see `main.yml`). Packer supplies the SSH connection.

## Time sync
chrony (not timesyncd): `tasks/chrony.yml` + `files/chrony.conf`. Prefers hogwarts (192.168.4.196, serves NTP via `playbooks/time-server/`), with public pools as backup. The same tasks converge running nodes via `playbooks/kubernetes-gen3/00-time.yml`.
