# kubernetes-gen3

k3s on VMs from `terraform/hogwarts` (210 controller-1, 211/212 workers, 214 controller-2; template 901) and `terraform/chimaera` (215 controller-3, 216 worker-3; template 911), then Flux hands over to `home-kubernetes`.
**Status: plays 00–04 run 2026-11-07, then extended to 3 controllers + 3 workers (controller-2/3 and worker-3 joined with `--limit controller-1,<new nodes>`; all Ready, Calico + CoreDNS custom verified). `05-flux-operator.yml` deliberately NOT run: Flux handover waits for the `home-kubernetes` gen3 scaffolding ([plan](../../docs/plans/2026-11-07-gen3-flux-handover.md)).**
Run 00–04 only: `ansible-playbook -i inventories/gen3 $P/00-dns.yml $P/01-data-disk.yml $P/02-k3s-server.yml $P/03-cluster-addons.yml $P/04-k3s-agents.yml` (one invocation; 04 needs the token read in 02). `main.yml` includes 05, so don't use it until handover.

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

## What changed vs gen2 (and why)
- Dropped: containerd, swap, sysctls (in template 901), kubeadm/kubelet/helm install, kubeadm config, join hashes.
- Calico kept for NetworkPolicy/Istio parity → k3s runs `flannel-backend: none`, `disable-network-policy`, pod CIDR 10.244.0.0/16. Service DNS is now `10.43.0.10` (was 10.96.0.10).
- Disabled bundled `traefik`, `servicelb`, `local-storage`, `metrics-server` (Istio NodePort ingress via HAProxy, Longhorn default, Flux-managed metrics-server).
- Incident tuning kept as k3s args: etcd compaction/quota, leader-election timeouts (60/40/10s), worker kubelet reservations.
- CoreDNS: gen2 patched the `coredns` ConfigMap; k3s rewrites it, so gen3 uses `coredns-custom` (`local.abbottland.io` → Pi-hole, `nas.local.abbottland.io` → 192.168.4.124). Other names use the default upstream (gen2 forwarded everything to Pi-hole).

## Before / when first running
- Calico's HelmChart needs `bootstrap: true` (install job must run on the NotReady node). CNI paths needed no override; nodes went Ready.
- `clusters/prod-gen3` does not exist in `home-kubernetes` yet (needs cluster dir + `crds|infra|applications/prod-gen3` overlays, istio-cni k3s paths, prometheus control-plane scrape tweaks, re-sealed `op-credentials`). Flux will sit unreconciled until it does.
- HAProxy LXC needs gen3 backends (workers .42/.43, NodePorts 30080/30443) before traffic can reach gen3.
- Off-host etcd snapshot copy (NAS) not configured; only local snapshots every 6h.
- Etcd is 3 members: controller-1 (`cluster-init`), controller-2 (hogwarts), controller-3 (chimaera). `02-k3s-server.yml` joins the others one at a time with `server:` + token (`files/k3s-server-join-config.yaml.j2`). Retire controller-2 when dumbledore (ARM) joins. Losing hogwarts still loses quorum.
- Workers still register against controller-1 only; if it is down, running agents keep working but new joins fail.
