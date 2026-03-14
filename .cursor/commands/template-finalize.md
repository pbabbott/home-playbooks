
All steps have been run successfully to configure a vm in proxmox.  Now we need to convert it to a template (ie. finalize it).

Simply run this command:

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/finalize-template.yml
```