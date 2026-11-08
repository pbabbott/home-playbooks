# gen3 Flux handover to home-kubernetes (Flux bootstrapped 2026-11-07; home-kubernetes layers in progress, see home-kubernetes/docs/plans/2026-11-08-gen2-to-gen3-migration.md)

State: k3s cluster up (3 controllers + 3 workers, `~/.kube/gen3-config`), Calico + CoreDNS custom in place, Flux Operator installed via `05-flux-operator.yml` (podinfo only).

## home-kubernetes work (separate effort)
- Add `clusters/prod-gen3/` (00-crds, 01-infra, 02-apps, 03-flux-gitops kustomizations) and `crds|infra|applications/prod-gen3/` overlays on `base/`; update the hostname patches in `flux-gitops/kustomization.yaml`. Decide which `infra/base` components gen3 takes (sealed-secrets, onepassword, cert-manager, istio, longhorn, nas-storage, kube-prometheus-stack, pihole, external-dns).
- k3s-specific changes: istio-cni paths (`/var/lib/rancher/k3s/agent/etc/cni/net.d`, `/var/lib/rancher/k3s/data/current/bin`); k3s runs scheduler/controller-manager/etcd in one process, so adjust prometheus control-plane scraping; metrics-server comes from Flux (k3s one is disabled); Longhorn data path `/mnt/ssd` (already mounted on workers); service DNS is 10.43.0.10 (grep for hardcoded 10.96.0.10).
- Secrets: gen3 gets a new sealed-secrets key, so re-seal `op-credentials` for gen3 (`scripts/op-connect-secret.sh`).
- Avoid two clusters fighting over the same external-dns records / `*.local` names / image-update-automation pushes to `main` while gen2 is live.

## Infra
- HAProxy LXC: gen3 backends (workers .42/.43, NodePorts 30080/30443, send-proxy-v2) once ingress is in place.
- Off-host etcd snapshot copy to the NAS.

## Then
Run `05-flux-operator.yml` (needs the deploy key on the home-kubernetes GitHub repo).
