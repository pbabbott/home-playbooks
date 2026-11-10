# kubernetes-gen3

k3s on VMs from `terraform/hogwarts` (210 controller-1, 211/212 workers, 214 controller-2; template 901) and `terraform/chimaera` (215 controller-3, 216 worker-3; template 911), then Flux hands over to `home-kubernetes`.
**2026-11-10: chimaera was reinstalled (PVE 9.2.2; OS + controller-3 on the SATA SSD, worker-3 root + Longhorn disk on the NVMe pool `nvme-fast`); controller-3 and worker-3 were rebuilt and rejoined (3 etcd members, 6 nodes Ready). Both are cordoned as before; worker-3 is labelled for Longhorn but unschedulable until uncordoned.**
**Status: plays 00–04 run 2026-11-07, then extended to 3 controllers + 3 workers (controller-2/3 and worker-3 joined with `--limit controller-1,<new nodes>`; all Ready, Calico + CoreDNS custom verified). `05-flux-operator.yml` run 2026-11-07 against `home-kubernetes` `clusters/prod-gen3` (podinfo only) and verified with a full teardown + rebuild ([plan](../../docs/plans/2026-11-07-gen3-flux-handover.md)).**

```
ansible-playbook -i inventories/gen3 ./playbooks/kubernetes-gen3/main.yml
```
Key auth as `firebolt`; no vault needed (the join token is read from the controller at run time).

| Play | What |
|---|---|
| `00-dns.yml` | systemd-resolved routes `~local.abbottland.io` to Pi-hole (same as gen2) |
| `01-data-disk.yml` | workers: ext4 on `/dev/sdb` (Terraform data disk) mounted at `/mnt/ssd` for Longhorn |
| `02-k3s-server.yml` | k3s `v1.35.10+k3s1`, embedded etcd: controller-1 `cluster-init` (`files/k3s-server-config.yaml.j2`), other controllers join one at a time (`files/k3s-server-join-config.yaml.j2`); fetches kubeconfig to `~/.kube/gen3-config` |
| `03-cluster-addons.yml` | Calico (tigera-operator 3.27.3, VXLAN, MTU 1450) and CoreDNS custom config, via k3s's auto-deploy manifests dir |
| `04-k3s-agents.yml` | workers join with kubelet reservations |
| `05-flux-operator.yml` | Flux Operator + deploy-key secret + FluxInstance → `clusters/prod-gen3` |
| `99-flux-teardown.yml` | Removes Flux completely (not in `main.yml`); see below |

## Flux bootstrap and rebuild
- Bootstrap: `ansible-playbook -i inventories/gen3 ./playbooks/kubernetes-gen3/05-flux-operator.yml -e @./vault.yml` (needs `home-kubernetes` `clusters/prod-gen3` on `main`). The FluxInstance template (`files/flux-instance.yaml.j2`) must stay identical to `home-kubernetes/clusters/prod-gen3/flux-system/flux-instance.yaml` apart from the path. Secret and FluxInstance tasks use `run_once` (controllers share one cluster). The pause prompt is for confirming the deploy key; `~/.ssh/id_ed25519` is currently registered as a GitHub *account* key.
- Rebuild from scratch (tested): `99-flux-teardown.yml -e confirm_flux_teardown=true` (add `-e '{"flux_teardown_namespaces": ["podinfo"]}'` to also remove app namespaces), then 05. Without the teardown's manifest-file and `Addon` cleanup, k3s will not re-apply the unchanged operator HelmChart and 05 times out waiting for the CRD. Expect Ready in ~2 min: FluxInstance, GitRepository, `apps-ks`, podinfo HelmRelease (2 pods in `podinfo`).

## What changed vs gen2 (and why)
- Dropped: containerd, swap, sysctls (in template 901), kubeadm/kubelet/helm install, kubeadm config, join hashes.
- Calico kept for NetworkPolicy/Istio parity → k3s runs `flannel-backend: none`, `disable-network-policy`, pod CIDR 10.244.0.0/16. Service DNS is now `10.43.0.10` (was 10.96.0.10).
- Disabled bundled `traefik`, `servicelb`, `local-storage`, `metrics-server` (Istio NodePort ingress via HAProxy, Longhorn default, Flux-managed metrics-server).
- Incident tuning kept as k3s args: etcd compaction/quota, leader-election timeouts (60/40/10s), worker kubelet reservations.
- CoreDNS: gen2 patched the `coredns` ConfigMap; k3s rewrites it, so gen3 uses `coredns-custom` (`local.abbottland.io` → Pi-hole, `nas.local.abbottland.io` → 192.168.4.124). Other names use the default upstream (gen2 forwarded everything to Pi-hole).

## After joining a worker: MANUAL steps (not done by these plays)
The plays only get the node into k3s (`01-data-disk.yml` gives workers `/mnt/ssd`). Longhorn gets NO disk on the node until you label it:
```
kubectl --context prod-gen3 label node <node> node.longhorn.io/create-default-disk=true
kubectl --context prod-gen3 -n longhorn-system get nodes.longhorn.io   # node Ready, disk at /mnt/ssd
```
Controllers are deliberately unlabeled (no `/mnt/ssd`). A re-created node loses the label. Full checklist (open-iscsi, NFS client, NAS dirs, replica count, 1Password): `home-kubernetes/docs/ai-reference-gen3-manual-steps.md`.

## Before / when first running
- Calico's HelmChart needs `bootstrap: true` (install job must run on the NotReady node). CNI paths needed no override; nodes went Ready.
- `home-kubernetes` `clusters/prod-gen3` currently has only `apps-ks` (podinfo). Still needed for real workloads: `crds|infra` layers and overlays, istio-cni k3s paths, prometheus control-plane scrape tweaks, re-sealed `op-credentials`.
- HAProxy gen3 LXC (`192.168.6.29`) is deployed with backends (workers .42/.43, NodePorts 30080/30443); verified 2026-11-08 it answers 503 with backends DOWN until Istio ingress exists.
- Off-host etcd snapshot copy (NAS) not configured; only local snapshots every 6h.
- Etcd is 3 members: controller-1 (`cluster-init`), controller-2 (hogwarts), controller-3 (chimaera). `02-k3s-server.yml` joins the others one at a time with `server:` + token (`files/k3s-server-join-config.yaml.j2`). Retire controller-2 when dumbledore (ARM) joins. Losing hogwarts still loses quorum.
- Workers still register against controller-1 only; if it is down, running agents keep working but new joins fail.
