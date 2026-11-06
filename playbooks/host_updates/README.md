# playbooks/host_updates

Apt upgrades for `dumbledore` (Raspberry Pi) and `bananapi` (Banana Pi), with Pushover notifications.

**Status: unfinished, do not trust.** Kept to record the goal: automatic updates across the VMs and physical infra, driven by Ansible on a schedule, with Pushover telling me when each run finishes. The playbook was never completed or fully working, and it is untouched since January 2024. Reviving it means dusting it off and testing it first.

## Playbooks

| File | Purpose |
|---|---|
| `pi.yml` | On `dumbledore` and `bananapi` (a Raspberry Pi and a Banana Pi, `inventories/physical`): `apt` upgrade with cache update, then check `/var/run/reboot-required`. Notifies via Pushover on completion, on reboot required, and on failure (priority 1). **Never reboots.** |

Run from the repo root (default inventory is `physical`):

```sh
ansible-playbook -e @./vault.yml playbooks/host_updates/pi.yml
```

> Unverified: exact working command and last successful run are unknown.

## Required variables

| Variable | Source |
|---|---|
| `pushover.app_token`, `pushover.user_key` | Vault (`vault.yml`). Key names confirmed present. |
| `inventoryPasswords.dumbledore`, `inventoryPasswords.bananapi` | Vault; SSH/sudo passwords used by `inventories/physical/hosts.yml`. |

## Why things are the way they are

- **Notify on every run, not just failures.** There was no trust that a scheduler would actually run, so a success message acted as a heartbeat. A better failure-handling approach likely exists (see TODOs).
- **Reboot notification only.** Good enough for now. `bananapi` is also the DNS server, so a reboot takes DNS down.

## Heads up

`bananapi` hosts the Pi-hole (see [`../dns`](../dns/README.md)). Upgrading and rebooting it affects DNS for anyone using it.

## TODO / open questions

- Dust off and verify the playbook end to end before relying on it; confirm the working command.
- Scheduling is unresolved: the goal is to run on a schedule (cron, AWX, CI?). Nothing is set up.
- Better failure/heartbeat handling than a success notification on every run.
- Make real reboots work (reboot when required, wait for the host, confirm services such as Pi-hole are back).
- Extend to the other hosts (VMs, k8s nodes, other physical hosts); today only the two Pis are targeted.
- Handlers are named `Notify ...` and the failure notification sits in `rescue`; check that handlers still fire as intended on current Ansible.
