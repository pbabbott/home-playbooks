A fleet of new prod VMs were just re-created.  We need to trust each of their fingerprints.

For each "<ip-address>" found in `inventories/prod/hosts.yml` perform the following two steps:

## 1. Remove the old fingerprint:

```sh
ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "<ip-address>"
```

## 2. Add the new fingerprint:
```sh
until ssh-keyscan -H "<ip-address>" >> "/home/vscode/.ssh/known_hosts" 2>/dev/null; do
  sleep 2
done
```