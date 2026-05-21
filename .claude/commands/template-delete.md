Stop and destroy VM 901 on proxmox host chimaera (192.168.4.192).

Run these commands over SSH on the proxmox host:

```sh
ssh root@192.168.4.192 "qm stop 901"
```

Wait for the VM to stop, then destroy it:

```sh
ssh root@192.168.4.192 "qm destroy 901"
```

Run stop first, confirm it succeeds, then run destroy. Report each result.
