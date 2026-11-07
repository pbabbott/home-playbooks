# Incident: hogwarts dropped off the network (e1000e TX hang)

Date: 2026-11-07. Impact: hogwarts and everything on it unreachable for roughly 17 minutes (about 14:03 to 14:20 local).
Resolved by a manual reboot; mitigated afterwards with `playbooks/hogwarts-network/`.

## Summary
The onboard Intel NIC on hogwarts (`nic0`, `e1000e`, PCI `0000:80:1f.6`) stopped transmitting ("Detected Hardware Unit Hang").
The link stayed up, so nothing alerted, but the host, its VMs and LXC all vanished from the LAN. The gen3 k3s cluster lost etcd
quorum because two of its three controllers live on hogwarts. Nothing else was lost: gen3 carried no production traffic yet, and
gen2 on chimaera was unaffected.

## Timeline (local time, 2026-11-07)
| Time | Event |
|---|---|
| 13:51 | VM 214 (`tf-prod-k3s-controller-2`) created and started on hogwarts, then joined to etcd |
| ~13:5x to 14:0x | controller-3 and worker-3 on chimaera joined the cluster (Ansible runs, k3s/Calico image pulls over the LAN) |
| 14:03:02 | first `e1000e ... nic0: Detected Hardware Unit Hang` in the kernel log; repeated every 2 s (499 times) until reboot |
| ~14:03 | hogwarts, 192.168.6.41-44 and .29 unreachable; chimaera's ARP for them `FAILED`; controller-3 logs `ReadIndex ... took too long`, API handler timeouts |
| ~14:19 | reboot requested (shutdown logged `pve-cluster.service` killed on timeout, watchdog not stopped cleanly) |
| 14:20 | hogwarts back at 192.168.4.196; VMs 210/211/212/214 and LXC 213 autostarted; gen3 re-formed quorum on its own, 6 nodes Ready |

## How it was diagnosed
- Container could reach the internet, chimaera, the NAS, Pi-hole and gen2 over TCP (ICMP is blocked from the container, so ping is
  misleading), but not hogwarts or any VM on it.
- From chimaera (same L2): `ping` down, `ip neigh` showed `FAILED` for 192.168.4.196 / 6.41 / 6.44 and `INCOMPLETE` for 6.29.
  Chrony on controller-3 last heard from hogwarts about 650 s before the check.
- After the reboot, `journalctl -b -1 -k` on hogwarts shows the hang messages.

## Evidence to compare next time
Run on hogwarts (`ssh root@192.168.4.196`):
```
journalctl -b -1 -k | grep -m1 "Hardware Unit Hang"       # first occurrence (use -b 0 if no reboot yet)
journalctl -b -1 -k | grep -c "Hardware Unit Hang"         # count
journalctl -b -1 -k | grep -B3 -m1 "Hardware Unit Hang"    # what happened just before
ethtool -k nic0 | grep -E "(tcp-segmentation|generic-segmentation|generic-receive)-offload"
ethtool -i nic0                                            # driver e1000e, firmware 0.5-4
```
Signature of the hang: `TDH` and `next_to_clean` stuck at the same values (`<92>` here), `next_to_use` `<e0>`, same `time_stamp`
repeating, `MAC Status <80083>`, `PHY 1000BASE-T Status <3c00>`. Versions at the time: pve-manager 9.2.2, kernel 7.0.2-6-pve,
e1000e firmware 0.5-4. Bridge: `vmbr0` over `nic0`.

## Cause
Known e1000e (I219) behaviour: the TX ring hangs with TCP/generic segmentation offload enabled; the driver detects it but the
reset does not recover the link. TSO, GSO and GRO were all on. Likely trigger: bursts of bridged traffic from the new etcd joins and
image pulls minutes earlier, but that is not proven. A second cause (driver or kernel regression in 7.0.2-6-pve) is not ruled out.

## What was changed
`playbooks/hogwarts-network/main.yml` (run with `-i inventories/physical -e @./vault.yml`): installs `ethtool`, adds
`post-up ethtool -K nic0 tso off gso off gro off` under `iface nic0 inet manual` in `/etc/network/interfaces`, and applies it live
(no link flap). Verified `tcp-segmentation-offload`, `generic-segmentation-offload`, `generic-receive-offload` are `off`.

## If it happens again
1. Offloads off did not prevent it: pin the previous kernel (`proxmox-boot-tool kernel list`) or check for a newer `e1000e`/kernel; consider
   a USB or add-in NIC for `vmbr0`.
2. Reboot (the hung NIC does not recover on its own), then collect the evidence above before it rotates out of the journal
   (`journalctl --list-boots`; check the journal is persistent: `ls /var/log/journal`).
3. gen3 recovers by itself once hogwarts is back; verify with `kubectl --context prod-gen3 get nodes`.

## Follow-ups
- gen3 etcd has 2 of 3 members on hogwarts, so any hogwarts outage costs quorum (see `playbooks/kubernetes-gen3/README.md`);
  dumbledore (offline) is the real fix.
- No alerting caught this (the link was up). Consider an external ping/NTP-reachability alert for hogwarts.
