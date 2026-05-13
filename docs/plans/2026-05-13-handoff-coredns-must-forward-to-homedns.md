# DNS Handoff: CoreDNS Must Forward to Home DNS

## Problem

Pods in both clusters cannot resolve `*.local.abbottland.io` hostnames. This breaks
CI integration tests — the GitHub Actions runner pod fails to reach `op-connect.local.abbottland.io`
and cannot fetch secrets from 1Password Connect.

**Confirmed error from CI log:**
```
dial tcp: lookup op-connect.local.abbottland.io on 10.96.0.10:53: no such host
```

## Root Cause

CoreDNS in both clusters is configured with `forward . /etc/resolv.conf`. This relies
on the node's `/etc/resolv.conf` to resolve unknown hostnames. The nodes are NOT
configured to use `192.168.4.144` (the home DNS that knows about `local.abbottland.io`),
so custom hostnames go unresolved.

Both clusters are affected — their CoreDNS configs are identical.

**Clusters:**
| Cluster | Nodes (IPs) |
|---|---|
| prod-gen2 | 192.168.6.24–27 |
| nonprod-gen2 | (same pattern) |

**Current broken CoreDNS forward:**
```
forward . /etc/resolv.conf {
   max_concurrent 1000
}
```

## Fix

Replace the `forward` directive to point directly at `192.168.4.144` (home DNS server).

**Target CoreDNS Corefile:**
```
.:53 {
   errors
   health {
      lameduck 5s
   }
   ready
   kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
      ttl 30
   }
   hosts {
      192.168.4.124 nas.local.abbottland.io
      fallthrough
   }
   prometheus :9153
   forward . 192.168.4.144 {
      max_concurrent 1000
   }
   cache 30 {
      disable success cluster.local
      disable denial cluster.local
   }
   loop
   reload
   loadbalance
}
```

## Ansible Task

Patch the CoreDNS ConfigMap on every cluster after kubeadm init. CoreDNS
automatically reloads when the ConfigMap changes (the `reload` plugin is enabled).

```yaml
- name: Configure CoreDNS to use home DNS for external resolution
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: coredns
        namespace: kube-system
      data:
        Corefile: |
          .:53 {
             errors
             health {
                lameduck 5s
             }
             ready
             kubernetes cluster.local in-addr.arpa ip6.arpa {
                pods insecure
                fallthrough in-addr.arpa ip6.arpa
                ttl 30
             }
             hosts {
                192.168.4.124 nas.local.abbottland.io
                fallthrough
             }
             prometheus :9153
             forward . 192.168.4.144 {
                max_concurrent 1000
             }
             cache 30 {
                disable success cluster.local
                disable denial cluster.local
             }
             loop
             reload
             loadbalance
          }
  tags:
    - dns
    - coredns
    - post-init
```

## Verification

After applying, exec into any pod and confirm resolution works:

```bash
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup op-connect.local.abbottland.io
```

Expected: resolves to the IP served by `192.168.4.144`.

## Notes

- `nas.local.abbottland.io` → `192.168.4.124` is already hardcoded in the `hosts` block.
  Keep that entry — it is a static override that does not depend on home DNS.
- If `192.168.4.144` ever changes, update both this file and the Ansible playbook.
- The `op-connect` 1Password Connect server runs in-cluster at ClusterIP `10.101.1.167`
  (prod-gen2, `op-connect` namespace). The hostname `op-connect.local.abbottland.io`
  resolves externally via home DNS and routes through the cluster ingress — not the
  ClusterIP — so fixing CoreDNS forward is the right layer to fix, not adding a hosts
  entry pointing at the ClusterIP.
