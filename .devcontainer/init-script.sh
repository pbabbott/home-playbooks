#!/usr/bin/env bash
set -euo pipefail

# Set up git origin to resolve push warning
git config --global push.autoSetupRemote true

# Load repo aliases into the interactive zsh session.
# Oh My Zsh auto-sources *.zsh files under $ZSH_CUSTOM, so we drop a tiny
# wrapper there that sources the repo alias file.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIAS_FILE="${SCRIPT_DIR}/aliases.sh"

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
TARGET_FILE="${ZSH_CUSTOM_DIR}/home-playbooks-aliases.zsh"

mkdir -p "${ZSH_CUSTOM_DIR}"

cat > "${TARGET_FILE}" <<EOF
# Auto-loaded by Oh My Zsh (devcontainer). Sourced from the repo aliases file.
if [ -f "${ALIAS_FILE}" ]; then
  source "${ALIAS_FILE}"
fi
EOF

echo "Configuring Claude"
CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$CLAUDE_JSON" ]; then
  tmp=$(mktemp)
  jq '.hasCompletedOnboarding = true' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
else
  printf '{"hasCompletedOnboarding":true}\n' > "$CLAUDE_JSON"
fi
