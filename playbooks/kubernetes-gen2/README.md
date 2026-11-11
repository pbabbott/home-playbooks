# playbooks/kubernetes-gen2

Installs Kubernetes (kubeadm) onto the Terraform-created Ubuntu VMs of the **gen2** clusters (prod and non-prod), then bootstraps Flux so [`home-kubernetes`](https://github.com/pbabbott/home-kubernetes) takes over.

**Status: live.** Runs both gen2 clusters. Gen3 will lean on k3s to simplify install and upgrades; this directory is the reference for what gen2 does. The non-prod cluster is currently powered off (Proxmox `chimaera` ran out of resources), so nothing here has been run recently against it.

## Where it fits

1. [`ansible-template-ubuntu-noble`](../ansible-template-ubuntu-noble/README.md) builds the Proxmox VM template on `chimaera`.
2. `terraform/` clones it into the fleet of VMs.
3. **This directory** installs k8s on each VM, using the matching inventory.
4. Flux (via `home-kubernetes`) deploys everything else.

## Result

After `main.yml` the cluster should be live and ready to host workloads: the controller is initialized, workers are joined, Calico is running, Flux is syncing `clusters/prod-gen2` or `clusters/non-prod-gen2`. A few steps are still manual, see [Manual steps](#manual-steps).

## Run

From the repo root. Inventory choice is required (the default is `physical`, which has no k8s hosts):

```sh
ansible-playbook -e @./vault.yml -i inventories/nonprod ./playbooks/kubernetes-gen2/main.yml
ansible-playbook -e @./vault.yml -i inventories/prod ./playbooks/kubernetes-gen2/main.yml
```

Each numbered playbook can also be run alone (same flags). Order matters, e.g. Helm installs need a cluster.

| Inventory | Controller | Workers |
|---|---|---|
| `inventories/prod` | `tf-prod-k8s-controller-1` (192.168.6.24) | `tf-prod-k8s-worker-1..3` (192.168.6.25-27) |
| `inventories/nonprod` | `tf-nonprod-k8s-controller-1` (192.168.6.31) | `tf-nonprod-k8s-worker-1..3` (192.168.6.32-34) |

All hosts: user `firebolt`, groups `kubernetes_controllers` / `kubernetes_workers`.

## Playbooks

`main.yml` imports these in order. The split is for human readability, not a hard design; it may change.

| File | Hosts | What it does |
|---|---|---|
| `00-dns.yml` | all | systemd-resolved: send `~local.abbottland.io` to Pi-hole (192.168.4.144). |
| `01-containerd.yml` | all | Docker apt repo, install `containerd.io`, `docker_permissions` role, copy `files/config.toml` (SystemdCgroup = true), restart. |
| `02-disable-swap.yml` | all | `swapoff -a`, comment out swap in fstab. |
| `03-ipv4-packets.yml` | all | `net.ipv4.ip_forward = 1` via `/etc/sysctl.d/k8s.conf`. |
| `04-kube-tools.yml` | all | pkgs.k8s.io **v1.35** repo; install and hold `kubectl`, `kubeadm`, `kubelet`. |
| `05-helm.yml` | all | Install Helm (buildkite apt repo). |
| `06-kubelet.yml` | see below | Cluster init, CoreDNS patch, Calico, worker join, control-plane tuning. |
| `07-flux-operator.yml` | controller | Flux Operator (Helm, OCI, v0.45.0), deploy-key secret, `FluxInstance`. |

`06-kubelet.yml` is the big one, in order:
1. Controller: `kubeadm init` with `files/kubeadm-config.yml.j2` (skipped if `/etc/kubernetes/admin.conf` exists); copy `admin.conf` to `~/.kube/config`; compute CA cert hash.
2. Controller: patch CoreDNS ConfigMap from `files/coredns-corefile.j2` (static host `nas.local.abbottland.io`, forward to Pi-hole).
3. Controller: install Calico (tigera-operator chart v3.27.3, `files/values.yml`, VXLAN, pod CIDR 10.244.0.0/16), then set `vxlanMTU` to 1450.
4. Workers: create a join token on the controller and `kubeadm join` (skipped if `/etc/kubernetes/kubelet.conf` exists).
5. Controller: re-assert etcd auto-compaction, etcd quota (2 GiB) and memory request, and leader-election timeouts in the static pod manifests (`lineinfile`). Workers: kubelet reserved resources.

Step 5's settings are also in `kubeadm-config.yml.j2`. The patches were fixes made along the way to already-running clusters (related: `docs/incidents/2026-05-10-etcd-fragmentation.md`).

## Files

- `files/config.toml`: containerd config.
- `files/kubeadm-config.yml.j2`: kubeadm Init/Cluster/Kubelet config. etcd data dir `/mnt/etcd` (dedicated disk from the template), pod subnet 10.244.0.0/16, leader-election and etcd tuning, kubelet reserved resources.
- `files/coredns-corefile.j2`: CoreDNS ConfigMap patch.
- `files/values.yml`: Calico (tigera-operator) values.
- `files/flux-instance.yaml.j2`: `FluxInstance` syncing `ssh://git@github.com/pbabbott/home-kubernetes.git`, `main`, path from `cluster_path`.

## Required variables

Most values are hardcoded at the top of each play or in the templates. This is deliberate: the playbooks fit this one homelab and are not meant to be portable.

| Variable | Source |
|---|---|
| `inventoryPasswords.kubernetes_node` | Vault (`vault.yml`). Used as SSH and sudo password for the hosts in both inventories (same password and keys for prod and nonprod). |
| `ansible_host`, `ansible_user` | `inventories/{prod,nonprod}/hosts.yml` |
| `cluster_path` | Play var in `07`: `clusters/non-prod-gen2` if the hostname contains `nonprod`, else `clusters/prod-gen2`. |
| `flux_operator_version`, Calico `chart_version`, k8s repo version | Hardcoded in `07`, `06`, `04`. |
| `~/.ssh/id_ed25519(.pub)` on the control machine | Flux deploy key, copied to the controller temporarily. |

Liveness check for these hosts: `../ping/k8s_hosts.yml`.

## Manual steps

- **Flux deploy key:** `07` copies the control machine's `~/.ssh/id_ed25519` to the controller to build the `flux-system` secret (then deletes it) and **pauses** for you to confirm the public key is a read-only deploy key at `github.com/pbabbott/home-kubernetes/settings/keys`.
- **Kubeconfig to your machine:** the playbook leaves it at `~/.kube/config` on the controller only; copy it down yourself.
- Possibly others; unknown, not yet audited (see TODOs).

## Known warts

- One controller per cluster, by design: `06` and `07` use `groups['kubernetes_controllers'][0]` for joins, and `kubeadm init` would run on every controller listed.
- Not a fully clean idempotent run: `06` generates a new init token every run, and several `command` tasks don't set `changed_when`.
- Pinned versions are scattered across plays (k8s v1.35, Calico v3.27.3, Flux Operator 0.45.0).
- Temp files are left in `/tmp` on the controller (`kubeadm-config.yml`, `coredns-patch.yml`, `values.yml`, `flux-instance.yaml`).
- Mixed module style (FQCN vs short names).
- Pi-hole IP (192.168.4.144) is hardcoded in `00-dns.yml` and the CoreDNS template; keep in sync with [`../dns`](../dns/README.md).

## TODO / open questions

- **Re-run safety is unverified.** Believed safe against a live cluster (init/join/Helm steps are guarded), but it has not been run for a long time. The non-prod cluster is off. Verify against non-prod before trusting it on prod.
- Audit remaining manual steps (kubeconfig copy-down, secrets beyond the Flux key, anything done by hand after the plays).
- Confirm whether `main.yml` works end-to-end on freshly cloned VMs.
- Decide what to carry into gen3 (k3s) and what to drop.
- Teardown/reset procedure for a node: unknown, not written down.
