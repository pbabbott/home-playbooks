# etcd Maintenance Report — 2026-05-10

## Problem

Source-controller in the `home-kubernetes` prod-gen2 cluster was crashing repeatedly (26 restarts over 8 days) with:

```
etcdserver: request timed out
Failed to renew lease → leader election lost → problem running manager
```

Root cause: etcd had no auto-compaction configured. Revision history accumulated indefinitely, growing the DB to 105 MB with **76% fragmentation** (only 26 MB actually in use). This caused every etcd read/write to take 100–280 ms (threshold: 100 ms), which caused leader lease renewals to time out, which caused controllers to crash.

## Immediate Fix Applied (home-kubernetes repo)

Manual compact + defrag run against prod-gen2 etcd on 2026-05-10:

```bash
etcdctl compact 15683906 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

etcdctl defrag \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

Result: **105 MB → 20 MB, 0% fragmentation.** Slow request warnings dropped to zero immediately.

This fix is temporary. Without auto-compaction, the DB will grow back.

## Permanent Fix Required (node management repo)

### Affected nodes

| Cluster | Control plane | etcd manifest path |
|---------|--------------|-------------------|
| prod-gen2 | `192.168.6.24` | `/etc/kubernetes/manifests/etcd.yaml` |
| non-prod-gen2 | `192.168.6.31` | `/etc/kubernetes/manifests/etcd.yaml` |

### What to change

Add two flags to the `etcd` command in each control plane's `/etc/kubernetes/manifests/etcd.yaml`:

```yaml
# Find the command array in spec.containers[0].command and add:
- --auto-compaction-mode=periodic
- --auto-compaction-retention=1h
```

Full diff example (prod-gen2):

```diff
   command:
   - etcd
   - --advertise-client-urls=https://192.168.6.24:2379
+  - --auto-compaction-mode=periodic
+  - --auto-compaction-retention=1h
   - --cert-file=/etc/kubernetes/pki/etcd/server.crt
   ...
```

### What these flags do

- `--auto-compaction-mode=periodic` — compacts on a time schedule (vs. revision-based)
- `--auto-compaction-retention=1h` — keeps 1 hour of revision history, discards the rest every hour

Kubernetes controllers only need a few seconds of revision history for watch resumption. 1 hour is generous and safe.

### How to apply

Editing the static pod manifest triggers an automatic etcd restart (kubelet detects the change). etcd will be down for ~10 seconds. Plan for a brief API server disruption on each control plane.

```bash
# SSH to control plane, then edit:
sudo vi /etc/kubernetes/manifests/etcd.yaml
# Add the two flags, save. kubelet restarts etcd automatically.
# Verify:
sudo crictl ps | grep etcd
```

Repeat for non-prod-gen2 control plane (`192.168.6.31`).

### If node config is Terraform/Ansible managed

If the etcd manifest is rendered by a template in your node management repo, find the template that generates `/etc/kubernetes/manifests/etcd.yaml` (usually a kubeadm config or an Ansible task) and add the flags there so they survive node reprovisioning.

### Recurring maintenance (until auto-compaction is live)

If auto-compaction cannot be applied immediately, run this monthly:

```bash
# Get current revision
REV=$(etcdctl endpoint status --write-out=json \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['Status']['header']['revision'])")

etcdctl compact $REV \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

etcdctl defrag \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key
```

## Health Indicators to Watch

After applying the permanent fix, verify via Grafana or `etcdctl endpoint status`:

- `DB SIZE` ≈ `IN USE` (fragmentation near 0%)
- `PERCENTAGE NOT IN USE` stays below 20%
- No `apply request took too long` warnings in etcd logs
- Source-controller restart count stops climbing
