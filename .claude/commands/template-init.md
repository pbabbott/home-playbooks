Initialize a proxmox Ubuntu Noble template from scratch.

## Steps

### 1. Create template in proxmox

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/create-ubuntu-template.yml
```

### 2. Start the template

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/start-vm-template.yml
```

### 3. Refresh SSH fingerprint for 192.168.6.91

Remove old fingerprint:

```sh
ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "192.168.6.91"
```

Add new fingerprint (retry until VM is up):

```sh
until ssh-keyscan -H 192.168.6.91 >> "/home/vscode/.ssh/known_hosts" 2>/dev/null; do
  sleep 2
done
```

Run all three steps in order. Report result of each step before continuing.
