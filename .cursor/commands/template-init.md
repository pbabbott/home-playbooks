
# Steps to initialized a template

## 1. Create template in proxmox 
Create a template in proxmox by running this command:

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/create-ubuntu-template.yml
```

## 2. Start the template
Start the template by running this command

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/start-vm-template.yml
```

### 3 - Setup SSH fingerprints

Since the VM was recreated, the SSH host key changed.

Remove the old fingerprint:

```sh
ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "192.168.6.91"
```

Add the new fingerprint:
```sh
until ssh-keyscan -H 192.168.6.91 >> "/home/vscode/.ssh/known_hosts" 2>/dev/null; do
  sleep 2
done
```