#!/usr/bin/env bash
# Source me before terraform init/plan/apply in a root that uses the pg backend:
#   source scripts/tfstate-env.sh
# Exports PG_CONN_STR for the terraform `pg` backend (credentials from 1Password item `terraform-state-db`).
_item=$(op item get terraform-state-db --vault Homelab --format=json) || return 1
_pw=$(jq -r '.fields[] | select(.id=="password") | .value' <<<"$_item")
_user=$(jq -r '.fields[] | select(.id=="username") | .value' <<<"$_item")
export PG_CONN_STR="postgres://${_user}:${_pw}@nas.local.abbottland.io:5432/terraform_state?sslmode=disable"
unset _item _pw _user
echo "PG_CONN_STR exported for terraform_state"
