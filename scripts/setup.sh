#!/usr/bin/env bash
# Install pinned third-party roles and collections into ./.ansible (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."
ansible-galaxy role install -r requirements.yml -p .ansible/roles
ansible-galaxy collection install -r requirements.yml -p .ansible/collections
echo
echo "Installed collections:"
ansible-galaxy collection list -p .ansible/collections
