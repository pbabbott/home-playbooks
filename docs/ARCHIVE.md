# Removed `archive/` directory

On 2026-11-06 the `archive/` directory was deleted from this repo. It held legacy Ansible
playbooks/roles used to install apps on VMs/Docker hosts before everything moved to the gen2
Kubernetes cluster (see the `home-kubernetes` repo). Nothing in it had been needed in over a year.

**The code is preserved at git tag `archive-final`** (commit `0eaba8e`, the last commit that
still contained `archive/`).

## What was in it (95 files)

- `archive/playbooks/`: asustor_services, backups, base_app_infra, code-server, dashy, dev_env,
  diun, dns, docker_cleanup, docker_registry, drone, grafana_loki, handbrake, home_assistant,
  mealie, npm_registry, prometheus, proxmox, semaphore, traefik, uptime_kuma
- `archive/roles/`: home.grafana-loki, home.traefik_app, home.verdaccio
- `archive/portainer/`

## How to look at it

```sh
git ls-tree -r archive-final --name-only -- archive/        # list files
git show archive-final:archive/playbooks/<name>/<file>      # read one file
git checkout archive-final -- archive/playbooks/<name>      # restore a dir into the worktree
```

On GitHub: https://github.com/pbabbott/home-playbooks/tree/archive-final/archive

If the tag is missing locally: `git fetch --tags`.

> Note for Claude: when asked to "check the archive in home-playbooks", search the
> `archive-final` tag with the commands above. Do not expect `archive/` on `main`.

---

# 2026-11 reorg removals

Preserved at git tag **`pre-reorg-2026-11`** (restore with `git checkout pre-reorg-2026-11 -- <path>`):

- `playbooks/kubernetes/` – gen1 k8s playbooks; gen1 VMs decommissioned
- `inventory.yml` gen1 hosts (`kubernetes_controller`, `kubernetes_worker_1-3`); remaining hosts moved to `inventories/physical/`
- `roles/` – 8 unreferenced `home.*` roles + `roles/requirements.yml`
- `ansible_collections/abbottland/{dns,ingress}` – unused; `core`/`docker` were kept in `collections/` until 2026-11-06, then removed (live roles inlined into playbooks; code in git history)
- `dockerconfig.txt` – contained a base64 registry credential (still in git history)

# Removed `collections/` (in-repo `abbottland.core` and `abbottland.docker`)

On 2026-11-06 the in-repo Ansible collection was deleted. Only three of its roles were still used
(`core.apt`, `docker.docker`, `docker.docker_permissions`); they are now inline tasks in
`kubernetes-gen2/01`, `04`, `05`, `workstation/docker.yml` and `pironman/main.yml`. The rest
(`core.pip`, `docker.docker_daemon`, `docker.docker_registry`, `docker.docker_plugins`) was unused
leftovers from `archive/`, along with their inventory vars.

**The code is preserved at git tag `collections-final`** (the last commit that still contained
`collections/`). Recover with `git show collections-final:collections/ansible_collections/abbottland/<path>`
or `git checkout collections-final -- collections`.

Behaviour change: the old `apt` role ran `apt upgrade` on every use; the inlined tasks only install
packages.
