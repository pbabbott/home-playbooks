# ansible-template-ubuntu-noble

Builds a Proxmox VM template (ID `901`, Ubuntu 24.04 "noble" cloud image) on the host `chimaera`.
Clones of it became the controller and worker nodes of the **gen2** Kubernetes clusters (prod and
non-prod). Terraform (`home-playbooks/terraform`) does the cloning; this directory only builds the template.

**Status: legacy, kept as reference** for building the gen3 cluster. It bootstrapped gen2 successfully
but is clunky (see [Known warts](#known-warts)). Mine it for ideas; don't treat it as a design to copy.

To run it, see [USAGE.md](USAGE.md).

## Result

A stopped, templated Proxmox VM that is ready to clone:

| Item | Value |
|---|---|
| VMID / name | `901` / `ansible-template-ubuntu-noble` |
| CPU / RAM | 4 cores, 6 GiB (balloon min 512 MiB) |
| `scsi0` | 60G root, `local-lvm` |
| `scsi1` | 256G on `fast-ssd`, ext4 label `longhorn`, mounted `/mnt/ssd` (Longhorn / general use), write-throttled (200 MB/s, 500 IOPS) |
| `scsi2` | 20G on `etcd-ssd`, ext4 label `etcd`, mounted `/mnt/etcd` (etcd data dir), unthrottled |
| Guest | qemu-guest-agent, `nfs-common`, `open-iscsi`, timezone America/Chicago + timesyncd config, iptables-legacy, IPv6 off |
| Cloud-init | user `firebolt` (password from vault), SSH key from the control machine, static IP, DNS |

## How it works

Two kinds of plays, targeting two different hosts:

**Against the Proxmox host (`chimaera`)** - copy a shell script over and run it with `qm`:
- `create-ubuntu-template.yml` -> `create-ubuntu-template.sh`: download the cloud image, create the VM, attach the three disks, set cloud-init.
- `start-vm-template.yml` -> `start-vm.sh`: boot the VM.
- `finalize-template.yml` -> `finalize-template.sh`: enable the guest agent, mark as template.

**Against the template VM** (inventory group `ansible-template-ubuntu-noble`, temporary IP 192.168.6.91) - `configure-vm.yml` imports, in order:
1. `01-qemu-guest-agent.yml` - install the agent
2. `02-memory-ballooning.yml` - verify `virtio_balloon` is present (check only)
3. `03-ssd-disks.yml` (+ `_format-and-mount-disk.yml`) - format and mount the two SSDs by UUID, with size sanity checks guarding against swapped device order
4. `04-timezone.yml` - timezone and `files/timesyncd.conf`
5. `05-iptables-ipv6.yml` - iptables-legacy, disable IPv6
6. `06-storage-packages.yml` - NFS and iSCSI (for Longhorn)
7. `07-clean-shutdown.yml` - `cloud-init clean`, empty `/etc/machine-id`, power off

Flow: create -> start -> configure (ends in shutdown) -> finalize.

## Why things are the way they are

- **IPv6 disabled.** IPv6 doesn't work well on the home network and caused problems. Homelab is small, IPv4 only, everywhere (a standing preference, also recorded in `CLAUDE.md`).
- **iptables-legacy.** Origin forgotten; it was done to support some Kubernetes feature. Unverified whether gen3 needs it.
- **Separate etcd and Longhorn disks.** gen2 ran on flaky hardware; the aim was to move IO-heavy workloads onto their own disks. Only partly successful.
- **Clean shutdown before templating.** Proxmox converts only a stopped VM into a template. The `cloud-init clean` and empty `machine-id` are what make clones unique (fresh cloud-init run, new machine-id and DHCP identity).
- **Guest agent disabled at creation, enabled at finalize.** The template is built with `agent=0` and switched on last, so Proxmox doesn't wait on an agent that isn't installed yet.
- **Shell scripts run on the Proxmox host.** No strong rationale; the code is a mix of hand-written and AI-written. Not a deliberate design.

## Known warts

- Hardcoded values: IP `192.168.6.91`, gateway/DNS, template ID `901`, storage names, `chimaera`.
- Two layers (Ansible wrapping bash `qm` calls) where Terraform or the `proxmox_kvm` module could do it directly.
- Template is configured by booting and mutating a VM rather than building an image reproducibly (e.g. Packer).
- `04-timezone.yml` has a note that it is a candidate to fold into `configure-vm`; it uses `shell`/`template` instead of FQCN modules.
- Slight inconsistency: header comments in some plays reference old play numbering.

## Other files

- [`manual-configure-vm-steps.md`](manual-configure-vm-steps.md) - the hand-run commands from before `configure-vm.yml` existed. Legacy, but a readable plain-shell version of what the plays do.
- `files/timesyncd.conf` - NTP config copied by `04-timezone.yml`.
