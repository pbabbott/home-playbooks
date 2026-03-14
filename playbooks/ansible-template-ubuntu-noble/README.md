# Steps to create a template

## 1 - Delete the existing template if it exist already

Go into proxmox and delete template 901

or simply run the cursor command: `/template-delete`

## 2 - Initialize template

2A, 2B & 2C can be executed with cursor command: `/template-create`

### 2 a - Create template

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/create-ubuntu-template.yml
```

### 2 b - Start template

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/start-vm-template.yml
```

### 2 c - Reset fingerprints

Remove old fingerprint
```sh
ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "192.168.6.91"
```

Get new fingerprint
```sh
ssh-keyscan -H 192.168.6.91 >> "/home/vscode/.ssh/known_hosts" 2>/dev/null;
```

## 3 - Configure the VM

Cursor command: `/template-configure`

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/configure-vm.yml
```

## 4 - Finalize

This basically just enables the guest-agent in proxmox and turns it into a template.

Cursor command: `/template-finalize`

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/finalize-template.yml
```