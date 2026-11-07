#!/usr/bin/env bash
# Back-compat wrapper: tfvars for hogwarts. Use tfvars-node.sh with NODE_ARG=chimaera for chimaera.
NODE_ARG=hogwarts exec "$(dirname "$0")/tfvars-node.sh" "$@"
