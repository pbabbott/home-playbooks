# Incident Resolution: Kubernetes Control Plane Instability

## What went wrong

The home Kubernetes cluster was experiencing outages where the control plane
would go down unexpectedly. The root cause was resource contention on a shared
storage disk.

Two workloads were competing for the same disk:

- **Longhorn** — the storage system that manages data for applications running
  in the cluster. It performs heavy, bursty write operations.
- **etcd** — the cluster's "brain." It stores all configuration and state for
  Kubernetes. It requires fast, reliable disk access to function correctly.

Both workloads were sharing one disk. When Longhorn hit a write burst, it
would monopolize the disk. etcd couldn't write fast enough, timed out, and the
control plane went down — taking the entire cluster with it.

## What was fixed

The storage disk was split into two independent disks, one for each workload.
etcd now has its own dedicated disk that Longhorn cannot touch.

Three additional safeguards were added:

1. **Write throttle on Longhorn's disk** — caps how aggressively Longhorn can
   write, so it cannot monopolize the underlying hardware even indirectly.

2. **Disabled storage power-saving mode** — the disk controller was allowed to
   idle between writes, causing stalls when a write arrived during idle. This
   is now permanently disabled.

3. **Isolation at the hardware queue level** — each disk has its own I/O
   channel inside the virtual machine, so they cannot interfere with each
   other even under heavy load.

## Current state

Both the production and non-production clusters are running. etcd is confirmed
healthy on both, using its dedicated disk. Longhorn continues to operate
normally on its own disk.

## Risk going forward

The two disks share the same physical SSD. A hardware failure of that SSD
would still affect both. A future improvement would be scheduled etcd backups
to a separate location so the cluster can be recovered quickly in that scenario.
