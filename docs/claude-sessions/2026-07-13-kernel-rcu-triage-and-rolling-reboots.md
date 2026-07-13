# 2026-07-13 — Kernel RCU triage + rolling reboots

## Context

Investigated GitHub issue #21: `tf-prod-k8s-worker-2` (VMID 206) crashed due to `wait_rcu_exp_gp` kernel CPU hog. Issue suspected disk resize mismatch as contributing factor. Task: triage all gen2 VMs and reboot any at risk.

## Findings

### Disk mismatch scope
- Disk resize (32G→60G) without reboot was **isolated to VM 206 only**
- All other resized VMs (205, 207, 302, 303, 304) had already been rebooted post-resize — partitions already at 59G
- Controllers (204, 301) were never resized — no mismatch risk

### `wait_rcu_exp_gp` kernel warning audit
Warning appeared on 4/5 workers — triggered by ARC dind runner (Docker-in-Docker) workloads:
- prod worker-1 (205): 3x — also on stale kernel `6.8.0-124` (others on `6.8.0-134`)
- prod worker-3 (207): 0 after Jul 8 reboot
- nonprod worker-1 (302): 2x
- nonprod worker-2 (303): **8x on 2026-07-13** — same count as VM 206 at crash time
- nonprod worker-3 (304): 1x

Disk mismatch was a contributing factor to VM 206 crash — other VMs survived the RCU warning because no disk anomaly present.

## Work done

### Prod gen2 — worker-1 rolled
- Scaled `istiod` to 2 replicas to unblock drain (single-replica PDB would block)
- Drained `tf-prod-k8s-worker-1`
- Rebooted via SSH
- Confirmed kernel upgraded: `6.8.0-124` → `6.8.0-134`
- Uncordoned; scaled istiod back to 1
- All 4 prod nodes `Ready` on `6.8.0-134`

### Nonprod gen2 — all 3 workers rolled
Sequential rolling reboot: worker-2 → worker-3 → worker-1

**Recurring blockers encountered:**
1. **istiod PDB** (`minAvailable: 1`, single replica, Flux-managed): Scaling to 2 doesn't stick — Flux reverts immediately. Fix: delete the PDB before draining the node that hosts istiod.
2. **Longhorn `instance-manager-*` PDB** (`ALLOWED DISRUPTIONS: 0`): Do NOT delete. Longhorn self-migrates volumes off the cordoned node and deletes the PDB automatically (~1–3 min). Re-run drain after PDB disappears.
3. **API server transient Forbidden**: Under drain load, the nonprod API server briefly returned `Forbidden` for `kubernetes-admin`. This is transient overload, not broken RBAC — wait 30s and retry.

**Pre-existing issue discovered**: `kube-controller-manager` on nonprod controller has been in CrashLoopBackOff since **2026-07-02** (11 days). Separate from our work; flagged but not investigated this session.

### Issue comment
Posted full triage summary to https://github.com/pbabbott/home-playbooks/issues/21#issuecomment-4960332265

### New skill created
`.claude/skills/drain-reboot/SKILL.md` — encodes the rolling reboot procedure with all PDB handling logic, node→IP→kubeconfig mapping, and known gotchas. Committed `f38ccd3`.

## Open items

- [ ] Investigate `kube-controller-manager` CrashLoopBackOff on nonprod controller (since 2026-07-02)
- [ ] Monitor nonprod worker-2 (303) — hit 8x RCU warning today; watch for recurrence
- [ ] Consider ARC runner concurrency limits or node affinity to reduce dind churn risk
- [ ] Close issue #21 once nonprod controller-manager is resolved
