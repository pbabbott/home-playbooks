# home-playbooks
Ansible playbooks for home infra

# Prerequsites

## Summary
In order to run this playbook, the following must be installed:

- python3
- pip3
- ansible
- paramiko

## Installation Commands

https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#prerequisites


PIP installation
```sh
$ curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
$ python get-pip.py --user
```

Ansible Installation
```sh
$ python -m pip install --user ansible
```
Packages Installation
```
$ sudo apt install -y sshpass


## Other Notes

Don't forget to add `~/.local/bin` to your path!

# Playbooks

## Requirements
Install requirements

```sh
$ ansible-galaxy install -r ./requirements.yml
```

## `main.yml`

```sh
ansible-playbook -e @./vault.yml main.yml
```

# Windows Hosts
```ps
winrm quickconfig

# Necessary if WSL is installed.
Enable-PSRemoting -SkipNetworkProfileCheck -Force

winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
```
