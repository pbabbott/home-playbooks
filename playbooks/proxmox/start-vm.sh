#!/usr/bin/env bash

TEMPLATE_ID="${TEMPLATE_ID:-901}"

# Boot the vm
echo "Booting the vm..."
qm start "$TEMPLATE_ID"


