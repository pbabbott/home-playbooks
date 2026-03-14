# Steps to create a template

## Delete the existing template

Go into proxmox and delete template 901

## Create and connect to the VM

### 1 - Create the template in proxmox
```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/create-ubuntu-template.yml
```

### 2 - Start the template vm

```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/start-vm-template.yml
```

### 3 - Determine the ip address of the vm

This is going to be `192.168.6.91` as its static.

### 4 - ssh into the vm

If you're re-creating, be sure to run this before:
```sh
ssh-keygen -f "/home/vscode/.ssh/known_hosts" -R "192.168.6.91"
```

```sh
ssh firebolt@192.168.6.91
```

type `yes` to continue.

Then logout. This is so we can more easily connect in the next step

## Configure the VM

You can run the playbook (ensure the template VM is started and reachable, e.g. at 192.168.6.91):

```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/configure-vm.yml
```

## Finalize

### 1 - Finalize the template

This basically just enables the guest-agent in proxmox and turns it into a template.

```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/finalize-template.yml
```