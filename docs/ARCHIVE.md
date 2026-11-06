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
