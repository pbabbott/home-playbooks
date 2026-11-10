# chimaera: host config captured 2026-11-10 (before the PVE 9.2.2 reinstall)

Captured from PVE 8.2.4. Layout then: NVMe (CT1000P3PSSD8, 1 TB) = OS + `local-lvm`; SATA SSD (CT2000BX500SSD1, 2 TB) = `etcd-ssd` + `fast-ssd`. Planned layout after reinstall: OS + controller-3 on the SATA SSD, worker-3 on the NVMe (see the wipe plan).

## storage.cfg
```
dir: local
	path /var/lib/vz
	content backup,iso,vztmpl,snippets
	shared 0

lvmthin: local-lvm
	thinpool data
	vgname pve
	content rootdir,images

lvmthin: etcd-ssd
	thinpool data
	vgname vg_etcd
	content images

lvmthin: fast-ssd
	thinpool data
	vgname vg_fast
	content images

```

## interfaces
```
auto lo
iface lo inet loopback

iface enp1s0 inet manual

auto vmbr0
iface vmbr0 inet static
	address 192.168.4.192/22
	gateway 192.168.4.1
	bridge-ports enp1s0
	bridge-stp off
	bridge-fd 0

iface wlo1 inet manual


source /etc/network/interfaces.d/*
```

## 60-ssd-power-mgmt.rules
```
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="max_performance"
```

## LVM before wipe
```
  PV             VG      Fmt  Attr PSize    PFree  
  /dev/nvme0n1p3 pve     lvm2 a--  <930.51g  16.00g
  /dev/sda1      vg_etcd lvm2 a--  <256.00g <12.56g
  /dev/sda2      vg_fast lvm2 a--    <1.57t  80.16g
  VG      #PV #LV #SN Attr   VSize    VFree  
  pve       1  31   0 wz--n- <930.51g  16.00g
  vg_etcd   1  10   0 wz--n- <256.00g <12.56g
  vg_fast   1  11   0 wz--n-   <1.57t  80.16g
NAME      SIZE MODEL           ROTA
sda       1.8T CT2000BX500SSD1    0
nvme0n1 931.5G CT1000P3PSSD8      0
```

The Proxmox API token was `root@pam!terraform` (privsep 0).
