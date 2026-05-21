Convert the configured VM into a proxmox template (finalize step).

```sh
ansible-playbook -e @./vault.yml ./playbooks/ansible-template-ubuntu-noble/finalize-template.yml
```

Run the command and report the result.
