# High Level Plan

The plan is to give each VM two separate virtual disks from the SSD: one dedicated to etcd (~10–20GB) and one for Longhorn. On your Proxmox host, use qm disk import or the GUI to add a second disk to each VM, then mount it in the VM and point etcd's --data-dir and --wal-dir at it. This gives etcd its own I/O queue completely separate from Longhorn traffic.

Once the disks are split, apply I/O throttling to the Longhorn disk on each VM via the Proxmox config. Edit /etc/pve/qemu-server/<vmid>.conf and add limits to the Longhorn disk entry, something like iops_wr=500,mbps_wr=200. Tune these numbers based on your SSD's specs — the goal is just to cap Longhorn's worst-case burst so it can't monopolize the controller. etcd's disk gets no throttle and runs unconstrained.

Finally, disable SSD power management on the Proxmox host so the controller never idles mid-write (echo 'max_performance' > /sys/class/scsi_host/host0/link_power_management_policy). Make that persistent via a udev rule or systemd unit so it survives reboots. With the disks split and Longhorn throttled, etcd should be fully insulated from storage contention.

# Specific implementation steps

<details needed here>