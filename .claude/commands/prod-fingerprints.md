Trust SSH fingerprints for all prod VMs after they were re-created.

Read `inventories/prod/hosts.yml` to get every IP address. For each IP:

1. Remove old fingerprint:
```sh
ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "<ip-address>"
```

2. Add new fingerprint (retry until host is up):
```sh
until ssh-keyscan -H <ip-address> >> "/home/vscode/.ssh/known_hosts" 2>/dev/null; do
  sleep 2
done
```

Process all IPs. Report which were updated.
