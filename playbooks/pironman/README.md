# playbooks/pironman

Sets up the [SunFounder Pironman case](https://www.sunfounder.com/products/raspberry-pi-4-case) on `dumbledore` (Raspberry Pi 4, `inventories/physical`). The case has an LCD panel on the front and an internal LED; both need SunFounder's software on the Pi.

**Status: partly working, untidy.** The install and the LED monitor work. `change_color.yml` does not. Not reviewed in a long time (last change March 2025). Dead-code cleanup is a TODO.

## How the LED color works

```
k8s API  --writes hex color-->  ~/pironman_monitor/color.txt  --inotify-->  monitor.sh  -->  sudo pironman -rc <hex>  -->  LED
```

- An API managed by k8s connects to `dumbledore` and writes the color into `color.txt`.
- `monitor.yml` installs a systemd service (`pironman_monitor.service`) that runs `monitor.sh`. It uses `inotifywait` on `color.txt` and, on each change, runs `sudo /usr/local/bin/pironman -rc <last line of the file>`.
- This asynchronous pattern exists because the pironman libraries could not be called from a Docker container, nor from an Ansible task (`change_color.yml`). They *do* work when invoked from the monitor service. Why is unknown.
- Informally this was called "the cron job", but it is a systemd service, not cron.

## Playbooks

Run from the repo root (inventory defaults to `physical`):

```sh
ansible-playbook -e @./vault.yml playbooks/pironman/main.yml
ansible-playbook -e @./vault.yml playbooks/pironman/monitor.yml
```

> Unverified: last run was a long time ago.

| File | Status | What it does |
|---|---|---|
| `main.yml` | works | Installs git/python tools, clones `github.com/sunfounder/pironman` at **`v2.0`** into `pironman_tools_directory`, runs `install.py --skip-reboot`, and adds the `dtoverlay` lines (`gpio-poweroff` pin 26, `gpio-ir` pin 13) to `/boot/config.txt`. No reboot is performed. |
| `monitor.yml` | works | Installs `inotify-tools`, creates `pironman_monitor_directory` and `color.txt`, copies `files/monitor.sh`, installs and starts the systemd unit. |
| `change_color.yml` | **broken** | Runs `pironman -rc 3AFCFF` via Ansible. Fails for unknown reasons. |

`main.yml` does not import `monitor.yml`, so a full setup currently needs both runs, in that order.

## Files

- `files/monitor.sh`: the inotify watcher. Hardcodes `/home/albus/pironman_monitor/color.txt`.
- `files/pironman_monitor.service.j2`: systemd unit. Hardcodes user `albus` and `/home/albus/pironman_monitor`; logs to `/var/log/pironman/watch-file.log`.
- `files/config.txt`: SunFounder's stock pironman config, a **leftover** from attempts to change the color by config file. Unused (the copy task in `main.yml` is commented out).

Check the service: `sudo systemctl status pironman_monitor.service`.

## Required variables

| Variable | Source |
|---|---|
| `pironman_tools_directory` (`/home/albus/pironman`), `pironman_monitor_directory` (`/home/albus/pironman_monitor`) | `inventories/physical/host_vars/dumbledore.yml` |
| `inventoryPasswords.dumbledore` | Vault; SSH/sudo password. |

## Why things are the way they are

- **SunFounder `pironman` repo at `v2.0`.** It followed SunFounder's setup docs for this case. Newer SunFounder tools may target newer cases and may not be backwards compatible; unchecked.
- **Many LED approaches were tried.** Only the file-watching service worked; the rest is dead code kept for now.

## TODO / open questions

- **Tidy up:** keep only the working code. Remove `change_color.yml`, the commented-out config copy and the `rgb_color` comment in `main.yml`, and `files/config.txt`, once confirmed unneeded.
- Decide whether `main.yml` should import `monitor.yml` so one command does the whole setup.
- Why the pironman libraries work from the service but not from Ansible or Docker.
- Confirm the `v2.0` repo is still correct for this Pi 4 case and the current OS; check whether `/boot/config.txt` should be `/boot/firmware/config.txt` on current Raspberry Pi OS.
- Name the k8s API that writes `color.txt` (and where it lives in `home-kubernetes`).
- Hardcoded `albus` paths in `monitor.sh` and the unit file; derive from variables.
- A reboot is needed for the `dtoverlay` changes; nothing does it.
- Confirm the working commands and run order.
