# Worker Root Disk Resize: 32G → 60G

**Date:** 2026-07-13  
**Scope:** k8s worker nodes only (not controllers)  
**Risk:** Low — online resize, no VM restart required

## Context

Root disk (`scsi0`) on all k8s workers is 32G on `local-lvm` (NVMe thin pool). This runbook
expands it to 60G. Workers only — controllers are not included.

This procedure also applies the pending `discard=on` fix from incident
`docs/incidents/2026-06-10-thin-pool-discard-not-configured.md`, since we are touching
the disk config anyway. This will allow fstrim to reclaim blocks and reduce NVMe thin pool pressure.

**Disks NOT touched:**
- `scsi1` → `/dev/sdb` → Longhorn (256G, fast-ssd) — leave alone
- `scsi2` → `/dev/sdc` → etcd (20G, etcd-ssd) — leave alone

## Node Reference

| Cluster  | k8s Node Name              | VMID | IP            |
|----------|----------------------------|------|---------------|
| non-prod | tf-nonprod-k8s-worker-1    | 302  | 192.168.6.32  |
| non-prod | tf-nonprod-k8s-worker-2    | 303  | 192.168.6.33  |
| non-prod | tf-nonprod-k8s-worker-3    | 304  | 192.168.6.34  |
| prod     | tf-prod-k8s-worker-1       | 205  | 192.168.6.25  |
| prod     | tf-prod-k8s-worker-2       | 206  | 192.168.6.26  |
| prod     | tf-prod-k8s-worker-3       | 207  | 192.168.6.27  |

Proxmox host: `ssh root@192.168.4.192`

## Strategy

1. Run full procedure against **non-prod** workers (302, 303, 304)
2. Validate non-prod — confirm disk grew, cluster healthy, thin pool utilization dropped
3. If non-prod clean, run same procedure against **prod** workers (205, 206, 207)

---

## Pre-flight Checks

Run from proxmox host:

```bash
# Thin pool must have headroom for expansion
# Growing 3 workers by 28G each = ~84G additional thin allocation needed
lvs pve --noheadings -o lv_name,data_percent,lv_size

# Verify current disk configs on target cluster
# For non-prod:
for vmid in 302 303 304; do
  echo "=== VMID $vmid ==="; qm config $vmid | grep scsi0
done

# For prod:
for vmid in 205 206 207; do
  echo "=== VMID $vmid ==="; qm config $vmid | grep scsi0
done
```

From kubectl:

```bash
# All nodes Ready
kubectl get nodes

# No critical pod failures
kubectl get pods -A | grep -Ev 'Running|Completed|Terminating'

# Longhorn volumes healthy (if Longhorn is installed)
kubectl -n longhorn-system get volumes 2>/dev/null || echo "Longhorn not present"
```

---

## Per-Worker Procedure

Repeat this sequence for each worker. Do one at a time — let each node fully rejoin before
moving to the next.

Replace `<VMID>`, `<NODE_NAME>`, and `<IP>` with values from the node reference table above.

### Step 1 — Cordon (kubectl)

```bash
kubectl cordon <NODE_NAME>
```

Drain is **not required** — the resize is fully online (no VM restart, no disk detach). Running
pods are unaffected. Cordon only prevents new pods from scheduling during the operation.

### Step 2 — Resize virtual disk (proxmox host)

```bash
# Extend the LV and update Proxmox config
qm resize <VMID> scsi0 60G

# Add discard=on (fixes incident 2026-06-10 on scsi0)
# Specify full disk config — keep iothread=1 and ssd=1 from original
qm set <VMID> --scsi0 local-lvm:vm-<VMID>-disk-0,discard=on,iothread=1,size=60G,ssd=1

# Confirm config shows 60G and discard=on
qm config <VMID> | grep scsi0
```

Expected output: `scsi0: local-lvm:vm-<VMID>-disk-0,discard=on,iothread=1,size=60G,ssd=1`

### Step 3 — Grow partition + filesystem (inside the VM)

SSH into the VM:

```bash
ssh admin@<IP>
```

Verify partition layout first — root is typically `sda3` on Ubuntu Noble cloud images:

```bash
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
```

Expected layout (Ubuntu Noble cloud image actual layout — verified against non-prod workers):
```
NAME    FSTYPE  SIZE MOUNTPOINT
sda              60G            ← virtual disk now shows 60G
├─sda1  ext4    ~59G /          ← root — this is what we grow
├─sda14           4M            ← BIOS boot partition
├─sda15 vfat   106M /boot/efi  ← EFI System Partition
└─sda16 ext4   913M /boot      ← boot partition
```

Root is `sda1`. The high partition numbers (sda14, sda15, sda16) for EFI/boot are standard
for Ubuntu Noble cloud images and do not follow sequential numbering.

```bash
# Grow partition 1 to fill the new disk space
sudo growpart /dev/sda 1

# Resize ext4 filesystem online (no unmount needed)
sudo resize2fs /dev/sda1

# Verify root filesystem now shows ~58G
df -h /
```

### Step 4 — fstrim (inside the VM)

```bash
# Return freed blocks to the thin pool (verify discard=on is set first: qm config <VMID> | grep scsi0)
sudo fstrim -v /
```

### Step 5 — Uncordon + verify (kubectl)

```bash
kubectl uncordon <NODE_NAME>

# Node should return to Ready within ~30s
kubectl get nodes

# Pods should reschedule onto the node
kubectl get pods -A -o wide | grep <NODE_NAME>
```

---

## Validation After All Non-prod Workers

Run this before touching prod.

```bash
# From proxmox host — thin pool utilization should have dropped after fstrim
lvs pve --noheadings -o lv_name,data_percent,lv_size

# From inside any non-prod worker — root should be ~59G
df -h /
lsblk | grep sda

# From kubectl
kubectl get nodes              # all Ready
kubectl get pods -A | grep -Ev 'Running|Completed'   # nothing broken
```

If all checks pass, proceed to prod.

---

## Template Update

After prod is complete, update the template script so future VM clones get 60G root disks:

File: `playbooks/ansible-template-ubuntu-noble/create-ubuntu-template.sh`, line 19:

```bash
# Change:
DISK_SIZE="32G"

# To:
DISK_SIZE="60G"
```

This takes effect the next time template VM 901 is rebuilt via `template-init` / `template-finalize`.
Existing VMs are not affected — this only governs new templates.

> **Note:** Terraform ignores disk changes (`lifecycle { ignore_changes = [disk] }`), so no
> Terraform changes are needed. The resize does not cause state drift.

---

## Rollback Notes

Online disk resize **cannot be reversed** without recreating the VM. However:

| Failure point | Action |
|---------------|--------|
| `qm resize` fails | No in-guest change has occurred — safe to retry or abandon |
| `growpart` fails | Disk is larger but partition is unchanged — safe to retry |
| `resize2fs` fails | Partition is grown but FS is not — retry `resize2fs /dev/sda1`; ext4 handles interrupted resize |
| Node won't rejoin k8s | Check `journalctl -u kubelet` on the node — resize does not affect kubelet config |
| VM won't boot | Boot rescue ISO, run `fsck /dev/sda1`, then retry `resize2fs` |

Shrinking the disk (back to 32G) requires recreating the VM from template and restoring data — avoid triggering this path.
