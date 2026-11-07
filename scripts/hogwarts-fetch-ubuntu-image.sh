#!/usr/bin/env bash
# Downloads the Ubuntu 24.04 cloud image to hogwarts' import dir, verified against Ubuntu's published SHA256.
# Needed because the Terraform API token lacks Sys.Modify (Proxmox URL downloads). Idempotent.
#   ./scripts/hogwarts-fetch-ubuntu-image.sh                      # current build
#   RELEASE=release-20251017 ./scripts/hogwarts-fetch-ubuntu-image.sh   # pin a specific build
set -euo pipefail

HOST=root@192.168.4.196
RELEASE=${RELEASE:-current}
BASE=https://cloud-images.ubuntu.com/noble/$RELEASE
DEST=/var/lib/vz/import/noble-server-cloudimg-amd64.qcow2   # referenced by terraform/hogwarts/templates.tf

SUM=$(curl -fsS "$BASE/SHA256SUMS" | awk '/ \*?noble-server-cloudimg-amd64.img$/ {print $1}')
[ -n "$SUM" ] || { echo "No checksum found at $BASE/SHA256SUMS" >&2; exit 1; }

ssh "$HOST" "set -e
mkdir -p /var/lib/vz/import
if [ -f $DEST ] && [ \"\$(sha256sum $DEST | cut -d' ' -f1)\" = $SUM ]; then echo 'Image already present and verified.'; exit 0; fi
wget -q -O $DEST.tmp $BASE/noble-server-cloudimg-amd64.img
[ \"\$(sha256sum $DEST.tmp | cut -d' ' -f1)\" = $SUM ] || { rm -f $DEST.tmp; echo 'Checksum mismatch' >&2; exit 1; }
mv $DEST.tmp $DEST && echo 'Image downloaded and verified.'"
