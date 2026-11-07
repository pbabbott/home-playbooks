# kubernetes-gen3

k3s on the hogwarts VMs (`terraform/hogwarts`, VMs 210–212 cloned from template 901), then Flux hands over to `home-kubernetes`.
**Status: written and syntax-checked, not yet run.**

```
ansible-playbook -i inventories/gen3 ./playbooks/kubernetes-gen3/main.yml
```
Key auth as `firebolt`; no vault needed (the join token is read from the controller at run time).

| Play | What |
|---|---|
| `00-dns.yml` | systemd-resolved routes `~local.abbottland.io` to Pi-hole (same as gen2) |
| `01-data-disk.yml` | workers: ext4 on `/dev/sdb` (Terraform data disk) mounted at `/mnt/ssd` for Longhorn |
| `02-k3s-server.yml` | k3s `v1.35.10+k3s1`, embedded etcd (`cluster-init`), config in `files/k3s-server-config.yaml.j2`; fetches kubeconfig to `~/.kube/gen3-config` |
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
- Verify nodes go Ready after Calico: k3s keeps CNI bin/conf under `/var/lib/rancher/k3s/...`; the chart values may need CNI path overrides.
- `clusters/prod-gen3` does not exist in `home-kubernetes` yet (needs cluster dir + `crds|infra|applications/prod-gen3` overlays, istio-cni k3s paths, prometheus control-plane scrape tweaks, re-sealed `op-credentials`). Flux will sit unreconciled until it does.
- HAProxy LXC needs gen3 backends (workers .42/.43, NodePorts 30080/30443) before traffic can reach gen3.
- Off-host etcd snapshot copy (NAS) not configured; only local snapshots every 6h.
- Adding chimaera/dumbledore controllers later: join with `server:` + the same token (dumbledore is ARM).
