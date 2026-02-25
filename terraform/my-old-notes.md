

# Procedure

## Step 1 - Get a cloud image

First, we need to get an `.img` file onto the proxmox server so it can be used to create VMs.  The easiest way to do this is to connect to the proxmox server via terminal and use the `wget` command to download one directly.

A terminal can be opened by going to `Datacenter > Chimera > Shell`

Need to "righ click" and "paste". CTRL V did not work for me.

```sh
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

## Step 2 - Create a template

Next, we need to create a VM using the `.img` we just downloaded.  This VM will not actually be started even once as it will be used as a template to create VMs.  The cloud img has special cloud-init settings which are only applied at fist boot, so its important not to boot this template vm.

I like to organize my VMs by ID.  My system is all VMs between 900-999 are templates!

```sh

TEMPLATE_ID=900

# Create a virtual machine
qm create $TEMPLATE_ID --memory 4096 --name ubuntu-cloud --net0 virtio,bridge=vmbr0

# Import the disk image we downloaded earlier
# local-lvm is the default place where VM disks are stored
qm importdisk $TEMPLATE_ID noble-server-cloudimg-amd64.img local-lvm

# change the storage settings for VM 900.
# set up a high-performance storage controller 
# and specifying where the VM's disk is located.
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$TEMPLATE_ID-disk-0

```

### Resize the vm

First, let's start by resizing aspects of the VM.  

To adjust the hard drive space, we can add an extra 20GB using this command:

```sh
$ qm resize $TEMPLATE_ID scsi0 +20G

  Size of logical volume pve/vm-900-disk-0 changed from 3.50 GiB (896 extents) to 23.50 GiB (6016 extents).
  Logical volume pve/vm-900-disk-0 successfully resized.
```

Next up, let's add more CPU cores.   I'm going to set mine to 4 cores per VM

```sh
$ qm set 900 -cores 4
```

In case 4096 of memory was not enough, you can always adjust memory too

```sh
qm set 900 --memory 6144
```

### Create a cloud init drive

```sh
# This command attaches a cloud-init drive to the VM 
qm set 900 --ide2 local-lvm:cloudinit

# This sets the boot order for the vm. the drive we created earlier is the one we want to boot to
qm set 900 --boot c --bootdisk scsi0

# This configures the serial and VGA settings for the vm. helpful for console-based management.
qm set 900 --serial0 socket --vga serial0
```

Notice, now that we've created another VM disk it shows up in `local-lvm`

### Configure cloud init

Username
```sh
# Sets the default username
qm set 900 --ciuser <username>
qm set 900 --ciuser firebolt # DELETE ME
```

Password 

```sh
# Sets the default password
qm set 900 --cipassword <password>
```

IP address
```sh
qm set 900 --ipconfig0 ip=dhcp
```

Copy a public key to the Proxmox server from local

```sh
# on local host

ssh-copy-id root@192.168.4.192
scp ~/.ssh/id_rsa.pub root@192.168.4.192:~/
```

Use this public key file for auth
```sh
qm set 900 --sshkey ~/id_rsa.pub
```

### finalize

```sh
# convert vm 900 to be a template
qm template 900

# set this vm to start on boot of proxmox
qm set 900 --onboot 1
```

## Step 3 - Start creating VMs

Now this is the fun part! I usually do this through the UI, but you can do it via command line as well
```sh
qm clone 900 200 --name k8s-controller-1
qm clone 900 201 --name k8s-worker-1
qm clone 900 202 --name k8s-worker-2
qm clone 900 203 --name k8s-worker-3
```

And now we can start them up!
```sh
qm start 200
qm start 201
qm start 202
```

## Step 4- Enable qemu-guest-agent
- Log onto each vm using the proxmox ui terminal
- `sudo apt install qemu-guest-agent`
- go back to proxmox and enable the guest agent in options
- reboot the vm
- all done!
	- optional: check the status of the agent
		- `sudo systemctl start qemu-guest-agent`


# Troubleshooting

oh no. dns is not working

i forgot to set ip=dhcp somewhere in this process
