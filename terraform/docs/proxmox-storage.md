# Proxmox Storage Overview

This document explains the different storage locations visible in the Proxmox VE interface on the `chimaera` node.

---

## Storage Types

### `local` (chimaera)

The `local` storage pool is a **directory-based storage** located at `/var/lib/vz` on the Proxmox host filesystem. It is enabled by default on every Proxmox installation.

**What it stores:**
- **ISO images** – installation media for VMs (`.iso` files)
- **CT Templates** – container templates used to create LXC containers
- **VZDump backup files** – backups created by Proxmox's built-in backup tool

**What it does NOT store:**
- VM disk images (those belong in block-level storage like `local-lvm`)

In this setup, `local` is using **5.69 GB of 100.86 GB** (about 5.6%), which is typical — it mostly holds ISOs and templates rather than active VM data.

---

### `local-lvm` (chimaera)

The `local-lvm` storage pool is an **LVM-Thin (Logical Volume Manager)** storage backend. It is also created by default during Proxmox installation and lives in the same physical disk/partition as `local`, but uses a separate LVM thin pool.

**What it stores:**
- **VM disk images** – the actual virtual hard drives for QEMU/KVM VMs (raw format)
- **CT volumes** – root filesystem volumes for LXC containers
- **Cloud-init drives** – small (~4 MB) drives used to pass configuration data to cloud VMs at first boot

**Why LVM-Thin?**
LVM-Thin supports **thin provisioning**, meaning you can allocate more disk space than physically exists and only use what's actually written. It also enables **fast snapshots and clones** without copying data upfront, which is why it's preferred for VM disks.

In this setup, you can see disk images for:
- VMs 200–203 (Kubernetes nodes) — 25.23 GB each
- VM 500 (marauders-map) — 72.48 GB
- VM 900 (ubuntu-cloud) — base template disk only (no active disk visible, just cloudinit)

---

### `longhorn-ssd` (chimaera)

This is a **custom storage pool** (not a default Proxmox storage) backed by an SSD. It stores large VM disk images for the Kubernetes worker nodes (VMs 201–203), each provisioned at **274.88 GB**.

The name `longhorn-ssd` suggests this storage is used to back [Longhorn](https://longhorn.io/), a distributed block storage system for Kubernetes. In this architecture, each worker node gets a large dedicated SSD-backed disk that Longhorn uses to provide persistent volumes to workloads running in the cluster.

---

## Summary Table

| Storage | Type | Primary Use | Notes |
|---|---|---|---|
| `local` | Directory | ISOs, CT templates, backups | Small footprint, not for VM disks |
| `local-lvm` | LVM-Thin | VM disks, CT volumes, cloud-init | Supports snapshots & thin provisioning |
| `longhorn-ssd` | LVM/Directory (SSD) | Large VM disks for K8s workers | Likely backing Longhorn distributed storage |

---

## Quick Rule of Thumb

> Use **`local`** for files (ISOs, templates, backups).  
> Use **`local-lvm`** or a dedicated storage pool for **running VM and container disks**.