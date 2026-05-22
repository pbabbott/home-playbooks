# 2026-05-21 — Flux Operator Bootstrap

## What we did

Integrated the Flux Operator bootstrap steps from `docs/plans/2026-05-21-bootstrap-flux-operator.md` into the gen2 Ansible playbooks so Flux is installed automatically when running `main.yml` against prod or nonprod.

## Files changed

- `playbooks/kubernetes-gen2/07-flux-operator.yml` — new playbook (added to `main.yml`)
- `playbooks/kubernetes-gen2/files/flux-instance.yaml.j2` — FluxInstance manifest template
- `playbooks/kubernetes-gen2/main.yml` — added `07-flux-operator.yml` import

## How the playbook works

1. Creates `flux-system` namespace (idempotent via stderr check)
2. Installs `flux-operator` v0.45.0 via Helm OCI (`oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator`) — skips if already deployed
3. **SSH key block** (skips entirely if `flux-system` secret already exists):
   - Copies `~/.ssh/id_ed25519` + `.pub` from control machine to controller at `/tmp/flux-deploy`
   - Runs `ssh-keyscan github.com` → `/tmp/known_hosts`
   - Creates `flux-system` k8s secret with `identity`, `identity.pub`, `known_hosts`
   - `always:` deletes both key files from controller — guaranteed even on failure
   - Pauses to confirm deploy key is added to GitHub
4. Templates `flux-instance.yaml.j2` → `/tmp/flux-instance.yaml` and applies it

## Key design decisions

- `cluster_path` auto-derived: `nonprod` in hostname → `clusters/non-prod-gen2`, else `clusters/prod-gen2`
- No `flux-instance.yaml` existed in `pbabbott/home-kubernetes` repo — playbook templates it directly rather than cloning
- `kubernetes.core.k8s` requires Python `kubernetes` lib (not present on controllers) — replaced namespace creation with `kubectl create namespace` + `failed_when` on stderr
- `spec.sync` not `spec.git` — learned from live CRD (`kubectl explain fluxinstance.spec.sync`)
- `pullSecret` not `secretRef` for the SSH secret reference

## Tested

Ran against nonprod and prod. Both clusters:
- FluxInstance `Ready` within ~60s
- All 6 controllers running (source, kustomize, helm, notification, image-reflector, image-automation)
- Flux v2.8.3

## Commit

`2397fbe` — `feat(k8s): add Flux Operator bootstrap to gen2 playbooks`
