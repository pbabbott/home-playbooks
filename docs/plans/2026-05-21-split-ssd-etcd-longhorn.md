# Execution Plan: Split SSD into etcd-ssd + fast-ssd

## Context

The 2TB SATA SSD (`/dev/sda`) was one LVM thin pool (`longhorn-ssd`) shared by
both Longhorn and etcd. Under heavy Longhorn write bursts the SSD controller
stalled, etcd fsyncs timed out, and the control plane went down.

All code changes are already committed in this repo. This document is the
execution sequence.

---

## Pre-conditions

- All gen2 cluster VMs (prod: 204–207, 301–304; nonprod: 201–203) are stopped or
  destroyed — they have disks on `vg_ssd` which will be wiped.
- Template 902 (if it exists on Proxmox) is also stopped/deleted — its SSD disk
  is on `vg_ssd`.
- You are running from the `home-playbooks` repo root.
- `vault.yml` is present for Ansible vault vars.

---

## Step 1 — Destroy existing cluster VMs

Destroy all VMs that have disks on `longhorn-ssd`. The Longhorn data is
disposable; clusters will be rebuilt from scratch.

```sh
# From terraform/ directory — destroys gen2 prod + nonprod VMs
terraform destroy
```

If any VM was not managed by Terraform, stop it manually on the Proxmox host:

```sh
ssh root@192.168.4.192 "qm list"
# qm stop <vmid> for any VM still running
```

Confirm no LVs in `vg_ssd` are open:

```sh
ssh root@192.168.4.192 "lvs --noheadings -o lv_name,lv_attr vg_ssd"
```

All entries should have `-` at position 6 of lv_attr (not `o`). If any show `o`,
find and stop the VM using that LV before continuing.

---

## Step 2 — Delete template 902 (if it exists)

Template 902 has an SSD disk on `vg_ssd`. Delete it before repartitioning.

```sh
ssh root@192.168.4.192 "qm status 902 && qm destroy 902 --purge || true"
```

---

## Step 3 — Repartition the SSD

**WARNING: This wipes all data on `/dev/sda`.** Steps 1 and 2 must be complete.

```sh
ansible-playbook -e @./vault.yml -e confirm=yes \
  ./playbooks/proxmox-host/repartition-ssd.yml
```

The playbook will:
- Remove `longhorn-ssd` from Proxmox storage config
- Wipe `vg_ssd` and `/dev/sda`
- Create two partitions: `sda1` (256 GiB, etcd) and `sda2` (remainder, general)
- Create `vg_etcd` + `vg_fast` with LVM thin pools
- Register `etcd-ssd` and `fast-ssd` in Proxmox

**Verify:**

```sh
ssh root@192.168.4.192 "pvesm status"
```

Expected output includes:
```
etcd-ssd   lvmthin   active   ...
fast-ssd   lvmthin   active   ...
```

```sh
ssh root@192.168.4.192 "lsblk /dev/sda"
```

Expected: `sda1` (~256G) and `sda2` (~1.6T).

---

## Step 4 — Disable SSD power management on the Proxmox host

```sh
ansible-playbook -e @./vault.yml \
  ./playbooks/proxmox-host/disable-ssd-power-mgmt.yml
```

**Verify:**

```sh
ssh root@192.168.4.192 "cat /sys/class/scsi_host/host*/link_power_management_policy"
```

All entries should show `max_performance`.

---

## Step 5 — Rebuild the VM template

Delete the existing template 901 if it exists:

```sh
# claude command: /template-delete
ansible-playbook -e @./vault.yml \
  ./playbooks/ansible-template-ubuntu-noble/create-ubuntu-template.yml
# or use the skill
```

Initialize the new template:

```sh
# claude command: /template-init
# This runs create-ubuntu-template.yml, start-vm-template.yml, and updates SSH fingerprints.
```

Manually, if needed:

```sh
ansible-playbook -e @./vault.yml \
  ./playbooks/ansible-template-ubuntu-noble/create-ubuntu-template.yml

ansible-playbook -e @./vault.yml \
  ./playbooks/ansible-template-ubuntu-noble/start-vm-template.yml

ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "192.168.6.91"
ssh-keyscan -H 192.168.6.91 >> "/home/vscode/.ssh/known_hosts" 2>/dev/null
```

Configure the template VM:

```sh
# claude command: /template-configure
ansible-playbook -e @./vault.yml \
  ./playbooks/ansible-template-ubuntu-noble/configure-vm.yml
```

`configure-vm.yml` now runs `03-ssd-disks.yml` which formats and mounts both
secondary disks:
- `/dev/sdb` (256G) → `/mnt/ssd` (label: longhorn)
- `/dev/sdc` (20G)  → `/mnt/etcd` (label: etcd)

**Verify on the template VM (192.168.6.91):**

```sh
ssh firebolt@192.168.6.91 "lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL"
```

Expected:
```
sdb  256G ext4  /mnt/ssd   longhorn
sdc   20G ext4  /mnt/etcd  etcd
```

```sh
ssh firebolt@192.168.6.91 "grep -E '/mnt/ssd|/mnt/etcd' /etc/fstab"
```

Both disks should have fstab entries.

Verify Proxmox template disk config:

```sh
ssh root@192.168.4.192 "qm config 901 | grep scsi"
```

Expected:
```
scsi1: fast-ssd:...,iops_wr=500,iothread=1,mbps_wr=200,ssd=1
scsi2: etcd-ssd:...,iothread=1,ssd=1
```

Finalize the template:

```sh
# claude command: /template-finalize
ansible-playbook -e @./vault.yml \
  ./playbooks/ansible-template-ubuntu-noble/finalize-template.yml
```

---

## Step 6 — Recreate cluster VMs

```sh
cd terraform/
terraform apply
```

Each cloned VM inherits both SSD disks from the template.

---

## Step 7 — Re-bootstrap the gen2 clusters

Follow the normal cluster bootstrap process in `playbooks/kubernetes-gen2/`.
The kubeadm config (`files/kubeadm-config.yml.j2`) now sets `dataDir: /mnt/etcd`,
so etcd will use the dedicated SSD disk on each control-plane node.

**Verify after bootstrap:**

```sh
# On a control-plane node (e.g. 192.168.6.24):
ssh firebolt@192.168.6.24 \
  "sudo grep data-dir /etc/kubernetes/manifests/etcd.yaml"
```

Expected: `--data-dir=/mnt/etcd`

```sh
kubectl -n kube-system get pod -l component=etcd
```

Expected: all etcd pods `Running`.

---

## What changed and why

| Change | File | Reason |
|--------|------|--------|
| Two SSD partitions, two VGs | host `repartition-ssd.yml` | Independent LVM metadata + Proxmox storage state — Longhorn pool failure can't take down etcd storage |
| Longhorn disk write throttle | `create-ubuntu-template.sh` | Cap Longhorn burst so it can't monopolize the SSD controller |
| Dedicated etcd disk (scsi2) | `create-ubuntu-template.sh` | Separate virtio-scsi controller + iothread = separate guest I/O queue |
| Disable ALPM | `disable-ssd-power-mgmt.yml` | Prevents controller idle-stall mid-write |
| `dataDir: /mnt/etcd` | `kubeadm-config.yml.j2` | Point etcd at the new dedicated disk |
| `03-ssd-disks.yml` | template configure | Formats + mounts both disks with size-sanity checks |
