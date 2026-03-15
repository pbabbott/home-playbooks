Connecting to my proxmox host (nickname chimaera) is normally done via this command:
`ssh root@192.168.4.192`

Now, we need to stop and destroy vm number 901.

```sh
qm stop 901
```

Wait a few moments...

```sh
qm destroy 901
```

