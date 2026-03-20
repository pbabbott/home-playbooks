#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Ubuntu Cloud-Init Template Bootstrap for Proxmox
# ------------------------------------------------------------
# This script creates a reusable Ubuntu cloud-init template.
# Terraform will clone from this template.
# Run once per Ubuntu release.
# ------------------------------------------------------------

TEMPLATE_ID="${TEMPLATE_ID:-901}"
TEMPLATE_NAME="${TEMPLATE_NAME:-ansible-template-ubuntu-noble}"
STORAGE="local-lvm"
BRIDGE="vmbr0"
MEMORY=6144
BALLOON=512
CORES=4
DISK_SIZE="32G"

CIUSER="${CIUSER:-admin}"
CIPASSWORD="${CIPASSWORD:-change-me}"

UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_FILE="noble-server-cloudimg-amd64.img"

### PRECHECKS ###
if qm status "$TEMPLATE_ID" &>/dev/null; then
  echo "VMID $TEMPLATE_ID already exists. Aborting."
  exit 1
fi

### DOWNLOAD IMAGE ###
if [ ! -f "$IMAGE_FILE" ]; then
  echo "Downloading Ubuntu cloud image..."
  wget -O "$IMAGE_FILE" "$UBUNTU_IMAGE_URL"
else
  echo "Image already downloaded."
fi

echo "Creating VM..."
qm create "$TEMPLATE_ID" \
  --name "$TEMPLATE_NAME" \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --net0 virtio,bridge="$BRIDGE" \
  --scsihw virtio-scsi-single \
  --ostype l26

echo "Setting balloon to $BALLOON..."
qm set "$TEMPLATE_ID" --balloon "$BALLOON"

echo "Importing disk..."
qm importdisk "$TEMPLATE_ID" "$IMAGE_FILE" "$STORAGE"

echo "Attaching disk..."
qm set "$TEMPLATE_ID" \
  --scsi0 "$STORAGE:vm-${TEMPLATE_ID}-disk-0,iothread=1,ssd=1" \
  --boot order=scsi0 \
  --bootdisk scsi0

echo "Resizing disk to $DISK_SIZE..."
qm resize "$TEMPLATE_ID" scsi0 "$DISK_SIZE"

echo "Adding cloud-init drive..."
qm set "$TEMPLATE_ID" --ide2 "$STORAGE:cloudinit"

echo "Disabling QEMU agent..."
qm set "$TEMPLATE_ID" --agent enabled=0

echo "Setting serial console..."
qm set "$TEMPLATE_ID" --serial0 socket --vga serial0

echo "Enabling auto-start..."
qm set "$TEMPLATE_ID" --onboot 1

echo "Setting user and password..."
qm set "$TEMPLATE_ID" --ciuser "${CIUSER}" --cipassword "${CIPASSWORD}"

echo "Setting SSH public key..."
qm set "$TEMPLATE_ID" --sshkey "/root/id_ed25519.pub"

echo "Setting static IP config..."
qm set "$TEMPLATE_ID" --ipconfig0 "ip=192.168.6.91/22,gw=192.168.4.1"

echo "Attaching SSD data disk..."
qm set "$TEMPLATE_ID" --scsi1 longhorn-ssd:256,iothread=1,ssd=1

echo "Setting DNS"
qm set "$TEMPLATE_ID" --nameserver "192.168.4.144 1.1.1.1"

echo ""
echo "Template $TEMPLATE_NAME (VMID $TEMPLATE_ID) created successfully."
echo "Note: template is not yet finalized."
