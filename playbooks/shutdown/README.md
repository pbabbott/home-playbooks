# shutdown

> **Status: out of date / not working right yet.** Do not rely on it.

Intended to cleanly shut down hosts (e.g. power down the k8s fleet). Known problems:

- Only targets `kubernetes_workers` and `kubernetes_controllers`, so it only works with `-i inventories/prod` or `-i inventories/nonprod`. Physical hosts (`inventories/physical`) are never targeted, so the `host_type == "physical"` task and the `shutdown_exempt` flag (set on `elder_wand`) currently do nothing.
- Both tasks are named "Shutdown ... hosts" and the play is named "Shutdown physical hosts", although it runs against VMs.
- No ordering: workers and controllers are shut down in the same play, with no drain/cordon of nodes first (see `.claude/skills/drain-reboot` for the safe rolling-reboot approach).
- Not recently verified against the current fleet.

Usage (as written):

```sh
ansible-playbook -e @./vault.yml -i inventories/nonprod playbooks/shutdown/main.yaml
```

TODO: decide the intended scope (k8s only vs. all hosts), fix ordering/draining, then update this README.
