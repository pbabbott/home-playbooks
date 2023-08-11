# base_app_infra

These playbooks are meant to be run in numerical order so that apps can start being deployed across my home infrastructure.

## 001_docker

This playbook installs the docker daemon on various target across the inventory.

Note docker needs to be installed before the other host installs, as pip depends on it.

## 002_host_installs

This playbook installs apt and pip packages across inventory hosts

## 003_dns

This playbook:
- runs pi hole as a docker container 
- sets various hosts use pi hole host machine as a dns server

## 004_reverse_proxy

This playbook sets up a reverse proxy server so that various apps can have an ingress.