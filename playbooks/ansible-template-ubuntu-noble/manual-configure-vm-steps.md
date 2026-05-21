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

### 3 - Mount the two secondary SSD disks

The template VM now has two SSD disks:
- `scsi1` → `/dev/sdb` (256G, fast-ssd) — Longhorn / general-purpose → `/mnt/ssd`
- `scsi2` → `/dev/sdc` (20G, etcd-ssd) — etcd data dir → `/mnt/etcd`

#### 3. A - Identify devices

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```

Expected output (before formatting):
```
sdb  256G
sdc   20G
```

#### 3. B - Format the Longhorn disk

```sh
sudo mkfs.ext4 -L longhorn /dev/sdb
```

#### 3. C - Format the etcd disk

```sh
sudo mkfs.ext4 -L etcd /dev/sdc
```

#### 3. D - Create mount points

```sh
sudo mkdir -p /mnt/ssd /mnt/etcd
```

#### 3. E - Mount the disks

```sh
sudo mount /dev/sdb /mnt/ssd
sudo mount /dev/sdc /mnt/etcd
```

#### 3. F - Make mounts persistent

```sh
sudo bash -c 'echo "UUID=$(blkid -s UUID -o value /dev/sdb) /mnt/ssd  ext4 defaults,noatime 0 2" >> /etc/fstab'
sudo bash -c 'echo "UUID=$(blkid -s UUID -o value /dev/sdc) /mnt/etcd ext4 defaults,noatime 0 2" >> /etc/fstab'
```

### 4 - Clean shutdown

```sh
sudo cloud-init clean
sudo truncate -s 0 /etc/machine-id
sudo poweroff
```