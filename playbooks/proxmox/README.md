## Steps to create a template

### 1 - Create the template in proxmox
```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/create-ubuntu-template.yml
```

### 2 - Start the template vm

```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/start-vm-template.yml
```

### 3 - Determine the ip address of the vm

Only way to do this is to check the router or use the console in proxmox.

### 4 - ssh into the vm
```sh
ssh admin@192.168.4.36
```

type `yes` to continue.

### 5 - install qemu guest agent

```sh
sudo apt update
sudo apt install -y qemu-guest-agent
```

### 6 - Memory Ballooning

Check that there is content in the directory. If there is, then the memory ballooning is working.
```sh
ls /sys/bus/virtio/drivers/virtio_balloon
```

### 7 - Clean shutdown

```sh
sudo cloud-init clean
sudo truncate -s 0 /etc/machine-id
sudo poweroff
```

### 8 - Finalize the template

```sh
ansible-playbook -e @./vault.yml ./playbooks/proxmox/finalize-template.yml
```