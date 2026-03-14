#!/usr/bin/env bash

TEMPLATE_ID="${TEMPLATE_ID:-901}"

### ENABLE QEMU AGENT ###
echo "Enabling QEMU agent..."
qm set "$TEMPLATE_ID" --agent enabled=1

## MARK AS TEMPLATE ###
echo "Marking as template..."
qm set "$TEMPLATE_ID" --template 1