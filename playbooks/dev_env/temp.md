Old code from previous attempts at dev env configuration.

```yaml
- hosts: room_of_requirement
  name: docker prereqs
  become: true
  tasks:
    - ansible.builtin.pip:
        name: docker
    - ansible.builtin.pip:
        name: docker-compose

- hosts: elder_wand
  name: Hello World
  tasks:
    - debug:
        msg: "hello user: {{ansible_date_time.date}}"

- name: test out windows module
  hosts: elder_wand
  tasks:
  - name: Get whoami information
    ansible.windows.win_whoami:

- hosts: rpi
  name: Hello World
  tasks:
    - debug:
        msg: "hello user: {{ansible_user}}"
    - debug:
        msg: deb [arch=arm64] https://download.docker.com/{{ ansible_system | lower }}/{{ ansible_distribution | lower }} {{ ansible_distribution_release }} stable
    - debug:
        msg: "{{ playbook_dir }}"


- name: Configure elder_wand
  hosts: elder_wand
  tasks:
    - name: Ping host
      win_ping: {}

- name: Install Tools
  hosts: all
  roles:
    - name: Configure Oh-My-ZSH
      role: gantsign.antigen_bundles
      users:
        - username:
          antigen_libraries:
            - name: oh-my-zsh
          antigen_theme:
            name: gallois
          antigen_bundles:
            - name: git
            - name: command-not-found
            - name: you-should-use
            - name: autojump
            - name: zsh-autosuggestions
```
