Fixes for bananapim5 (192.168.4.144)

Docker and boot

1. Wait for the network at boot.
   - Enable the wait-online service for whichever network manager the Pi uses: systemd-networkd-wait-online or NetworkManager-wait-online. Both are disabled now.
   - I haven't checked which one is in use. Check with systemctl is-active systemd-networkd NetworkManager.
2. Stop Docker giving up after quick failures. Add a drop-in at /etc/systemd/system/docker.service.d/override.conf:
[Unit]
StartLimitIntervalSec=0
[Service]
RestartSec=5
   Then run daemon-reload.
3. Make Docker start after the clock is synced and the network is up. In the same drop-in, add After=chrony.service network-online.target. Optionally add Wants=time-sync.target.
4. Reconsider metrics-addr in /etc/docker/daemon.json. It binds to 192.168.4.144:9323, which fails if eth0 has no address yet. Use 0.0.0.0:9323, or keep the IP once fix 1 is in place. This is a guess at the crash cause, not a confirmed one.
5. Reset the failed state and start Docker. Run systemctl reset-failed docker docker.socket, then start it. Do this only after a Pi-hole backup, since the containers are still running under live-restore.

NFS backups

6. Fix the fstab entry. Change it to 192.168.4.124:/volume1/Backups/pihole /mnt/pihole_backups nfs rw,hard,_netdev,nofail,x-systemd.automount 0 0.
7. Check that the export is reachable. Confirm the NAS allows the Pi's IP to mount /volume1/Backups/pihole. The mount failure may also be NAS-side, which I couldn't test.
8. Add a safeguard on the container's /backups bind mount. Today it falls back silently to the SD card's empty directory when the NFS mount is missing. Options are bind-propagation: rslave, or a systemd check that the mount is active before Pi-hole starts.

Pi-hole

9. Back up /home/pi/app_config/pihole/ (etc-pihole and etc-dnsmasq.d) before touching Docker.
10. Find where the compose file or run command lives, and put it under Ansible. I only saw the running containers, not their definition. There's also a third container (5f7c9e96…) I couldn't identify.
11. Check restart policies on all containers, so they come back cleanly after a reboot.

Hardening

12. Allow passwordless sudo for pi, limited to docker and systemctl, if you want me to handle this kind of fix directly.
13. Keep journal logs across reboots. The journal was truncated and rotated, which is why the crash cause is gone. Set Storage=persistent in journald.conf, and consider a larger SystemMaxUse.
14. Add an alert for docker.service being in the failed state, such as a node-exporter check. Port 9100 is already listening, so a systemd collector would work.

Items 1–6 and 13 are the ones that address the recurring failures.