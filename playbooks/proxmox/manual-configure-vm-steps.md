## Configure the VM

These were the steps I was running before I had `configure-vm.yml` created.

### 1 - install qemu guest agent

```sh
sudo apt update
sudo apt install -y qemu-guest-agent
```

### 2 - Check Memory Ballooning

Check that there is content in the directory. If there is, then the memory ballooning is working.
```sh
ls /sys/bus/virtio/drivers/virtio_balloon
```

### 3 - Mount the SSD

#### 3. A - Find the right device

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```
Identify the device that:
- Is 256G
- Has no FSTYPE
- Has no MOUNTPOINT
- Is NOT your root disk (your root disk will usually show / mounted)

It will very likely be the following:
```sh
sdb   256G
```

#### 3. B - Format the disk

```sh
sudo mkfs.ext4 -L data /dev/sdb
```

- Creates a filesystem on the device /dev/sdb.
- ext4 is the Linux filesystem being used.
- ⚠️ This erases everything currently on the disk.
- `-L data` is just a label

#### 3. C - Create a mount point

```sh
sudo mkdir -p /mnt/longhorn-ssd
```

- Creates the directory where the disk will be attached.
- `-p` ensures the directory (and any missing parents) are created safely.

#### 3. D - Mount the disk

```sh
sudo mount /dev/sdb /mnt/longhorn-ssd
```

- Attaches the filesystem on /dev/sdb to the directory /mnt/longhorn-ssd.
- After this, anything written to that directory is stored on the disk.

#### 3. E - Make the mount persistent

```sh
sudo bash -c 'echo "UUID=$(blkid -s UUID -o value /dev/sdb) /mnt/longhorn-ssd ext4 defaults,noatime 0 2" >> /etc/fstab'
```
- This adds an entry to /etc/fstab, which tells Linux what disks to mount during boot.

### 4 - Clean shutdown

```sh
sudo cloud-init clean
sudo truncate -s 0 /etc/machine-id
sudo poweroff
```