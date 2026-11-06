#!/usr/bin/env bash
# Generates ./vault_pass.txt (gitignored) from 1Password, for ansible.cfg's vault_password_file.
#
# Local usage:
#   ./scripts/vault-pass.sh            # skip if vault_pass.txt already exists
#   ./scripts/vault-pass.sh --force    # overwrite
#
# Requires the `op` CLI authenticated (OP_CONNECT_HOST / OP_CONNECT_TOKEN in the devcontainer) and jq.
# Item: "ansible_vault_pass" in the Homelab vault, field "password".

set -euo pipefail

cd "$(dirname "$0")/.."

OUT=./vault_pass.txt

if [ -s "$OUT" ] && [ "${1:-}" != "--force" ]; then
    echo "$OUT already exists (use --force to overwrite)."
    exit 0
fi

echo "Fetching ansible vault password from 1Password..."
PASS=$(op item get "ansible_vault_pass" --vault Homelab --format=json | jq -r '.fields[] | select(.id=="password") | .value')

if [ -z "$PASS" ] || [ "$PASS" = "null" ]; then
    echo "Error: could not read 'password' field from item 'ansible_vault_pass'." >&2
    exit 1
fi

umask 077
printf '%s\n' "$PASS" > "$OUT"
echo "Wrote $OUT"
