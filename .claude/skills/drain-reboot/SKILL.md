---
name: drain-reboot
description: Safely drain and reboot a single gen2 Kubernetes node (prod or nonprod). Handles Longhorn PDB blocking, istiod single-replica PDB, kubeconfig fetching, and node readiness verification. Use when asked to reboot, restart, or cycle a specific k8s node.
argument-hint: "[node-name]  e.g. tf-prod-k8s-worker-1 or tf-nonprod-k8s-worker-2"
disable-model-invocation: true
allowed-tools: Bash
---

# drain-reboot

Drain and reboot the node `$ARGUMENTS`, then uncordon and verify it returns healthy.

## Cluster & IP reference

| Node | IP | Controller IP | Kubeconfig path |
|------|----|--------------|-----------------|
| tf-prod-k8s-controller-1 | 192.168.6.24 | 192.168.6.24 | /tmp/prod-kubeconfig.yaml |
| tf-prod-k8s-worker-1 | 192.168.6.25 | 192.168.6.24 | /tmp/prod-kubeconfig.yaml |
| tf-prod-k8s-worker-2 | 192.168.6.26 | 192.168.6.24 | /tmp/prod-kubeconfig.yaml |
| tf-prod-k8s-worker-3 | 192.168.6.27 | 192.168.6.24 | /tmp/prod-kubeconfig.yaml |
| tf-nonprod-k8s-controller-1 | 192.168.6.31 | 192.168.6.31 | /tmp/nonprod-kubeconfig.yaml |
| tf-nonprod-k8s-worker-1 | 192.168.6.32 | 192.168.6.31 | /tmp/nonprod-kubeconfig.yaml |
| tf-nonprod-k8s-worker-2 | 192.168.6.33 | 192.168.6.31 | /tmp/nonprod-kubeconfig.yaml |
| tf-nonprod-k8s-worker-3 | 192.168.6.34 | 192.168.6.31 | /tmp/nonprod-kubeconfig.yaml |

SSH user for all nodes: `firebolt`

## Steps

### 1. Resolve node

From the table above, determine the node IP, controller IP, and kubeconfig path for `$ARGUMENTS`. If the node name is not in the table, stop and report an error.

### 2. Fetch kubeconfig

```bash
ssh -o StrictHostKeyChecking=no firebolt@<CONTROLLER_IP> \
  "sudo cat /etc/kubernetes/admin.conf" \
  | sed "s|server: https://127.0.0.1|server: https://<CONTROLLER_IP>|" \
  > <KUBECONFIG_PATH>
```

Verify with:
```bash
kubectl --kubeconfig <KUBECONFIG_PATH> get node $ARGUMENTS
```

If the node is not found or the API server is unreachable, stop and report.

### 3. Check for blocking PDBs

```bash
kubectl --kubeconfig <KUBECONFIG_PATH> get pdb -A
```

Note which PDBs have `ALLOWED DISRUPTIONS: 0`. Two known blockers:

- **istiod** (`istio-system`): single-replica deployment controlled by Flux — scaling to 2 won't stick. Delete the PDB before draining if istiod is on this node.
- **Longhorn instance-manager** (`longhorn-system`): self-manages. Do NOT delete it — wait for Longhorn to migrate volumes off the cordoned node, which it does automatically (PDB disappears when volumes migrate).

Check which node istiod is on:
```bash
kubectl --kubeconfig <KUBECONFIG_PATH> get pods -n istio-system -o wide | grep istiod
```

If istiod is on `$ARGUMENTS`, delete its PDB now:
```bash
kubectl --kubeconfig <KUBECONFIG_PATH> delete pdb istiod -n istio-system
```

### 4. Drain the node

```bash
kubectl --kubeconfig <KUBECONFIG_PATH> drain $ARGUMENTS \
  --ignore-daemonsets \
  --delete-emptydir-data
```

If drain blocks on a Longhorn `instance-manager-*` PDB:
- **Do not delete the PDB.**
- Wait. Longhorn migrates volumes automatically once the node is cordoned. The PDB will disappear when migration is complete (typically 1–3 min).
- Confirm no volumes remain attached to the node:
  ```bash
  kubectl --kubeconfig <KUBECONFIG_PATH> get volume.longhorn.io -n longhorn-system \
    -o wide | grep $ARGUMENTS
  ```
- Once the PDB is gone, re-run the drain command.

If the drain command fails due to API server timeout (connection refused), wait 30s and retry — the API server recovers.

### 5. Reboot

```bash
ssh -o StrictHostKeyChecking=no firebolt@<NODE_IP> "sudo reboot"
```

### 6. Wait for node Ready

Poll until the node returns to `Ready,SchedulingDisabled`:
```bash
until kubectl --kubeconfig <KUBECONFIG_PATH> get node $ARGUMENTS \
  | grep -q "Ready,Scheduling"; do sleep 10; done
```

Then verify SSH is up:
```bash
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
  firebolt@<NODE_IP> "uname -r" 2>/dev/null; do sleep 5; done
```

### 7. Uncordon

```bash
kubectl --kubeconfig <KUBECONFIG_PATH> uncordon $ARGUMENTS
```

### 8. Verify

```bash
kubectl --kubeconfig <KUBECONFIG_PATH> get nodes -o wide
```

Report:
- Node status (should be `Ready`)
- Kernel version from `uname -r` output
- Any nodes still `NotReady`

## Important notes

- Reboot one node at a time. Do not proceed to the next node until the current one is `Ready`.
- If `kubernetes-admin` gets `Forbidden` errors mid-operation, the API server is temporarily overloaded — wait 30s and retry. Do not assume RBAC is broken.
- If `kube-controller-manager` is in CrashLoopBackOff on the controller node, flag it as a separate issue but proceed with the reboot unless explicitly told otherwise.
- Longhorn degraded replicas will self-heal after reboot — no manual action needed.
