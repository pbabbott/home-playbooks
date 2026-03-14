
We need to configure a running vm which will soon be turned into a template.

Simply run this command:

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/configure-vm.yml
```