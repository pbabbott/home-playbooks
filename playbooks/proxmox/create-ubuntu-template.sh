#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Ubuntu Cloud-Init Template Bootstrap for Proxmox
# ------------------------------------------------------------
# This script creates a reusable Ubuntu cloud-init template.
# Terraform will clone from this template.
# Run once per Ubuntu release.
# ------------------------------------------------------------

### CONFIGURATION ###
# TEMPLATE_ID and TEMPLATE_NAME can be set by environment (e.g. by Ansible).
# Other settings are fixed for this playbook.

TEMPLATE_ID="${TEMPLATE_ID:-901}"
TEMPLATE_NAME="${TEMPLATE_NAME:-tf-template-ubuntu-noble}"
STORAGE="local-lvm"
BRIDGE="vmbr0"
MEMORY=6144
CORES=4
DISK_SIZE="32G"

CIUSER="${CIUSER:-admin}"
CIPASSWORD="${CIPASSWORD:-change-me}"

# DNS: match k8s worker (systemd-resolved primary + fallback)
PRIMARY_DNS="${PRIMARY_DNS:-192.168.4.144}"
FALLBACK_DNS="${FALLBACK_DNS:-1.1.1.1}"

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

### CREATE VM SHELL ###
echo "Creating VM..."
qm create "$TEMPLATE_ID" \
  --name "$TEMPLATE_NAME" \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --net0 virtio,bridge="$BRIDGE" \
  --scsihw virtio-scsi-pci \
  --ostype l26

### IMPORT DISK ###
echo "Importing disk..."
qm importdisk "$TEMPLATE_ID" "$IMAGE_FILE" "$STORAGE"

### ATTACH DISK ###
echo "Attaching disk..."
qm set "$TEMPLATE_ID" \
  --scsi0 "$STORAGE:vm-${TEMPLATE_ID}-disk-0" \
  --boot order=scsi0 \
  --bootdisk scsi0

### RESIZE DISK ###
echo "Resizing disk to $DISK_SIZE..."
qm resize "$TEMPLATE_ID" scsi0 "$DISK_SIZE"

### ADD CLOUD-INIT DRIVE ###
echo "Adding cloud-init drive..."
qm set "$TEMPLATE_ID" --ide2 "$STORAGE:cloudinit"

### ENABLE QEMU AGENT ###

echo "Enabling QEMU agent..."
qm set "$TEMPLATE_ID" --agent enabled=1

### SERIAL CONSOLE ###
echo "Setting serial console..."
qm set "$TEMPLATE_ID" --serial0 socket --vga serial0

### DO NOT AUTO-START ###
echo "Preventing auto-start..."
qm set "$TEMPLATE_ID" --onboot 0

## Setting user and password
echo "Setting user and password..."
qm set "$TEMPLATE_ID" --ciuser "admin" --cipassword "change-me"

### Setting SSH public key
echo "Setting SSH public key..."
qm set "$TEMPLATE_ID" --sshkey "/root/id_ed25519.pub"

### Setting ip config
echo "Setting IP config..."
qm set "$TEMPLATE_ID" --ipconfig0 "ip=dhcp"

### Setting DNS
echo "Setting DNS..."
qm set "$TEMPLATE_ID" --nameserver "${PRIMARY_DNS},${FALLBACK_DNS}" --searchdomain "local.abbottland.io"

### CONVERT TO TEMPLATE ###
echo "Converting VM to template..."
qm template "$TEMPLATE_ID"

echo ""
echo "Template $TEMPLATE_NAME (VMID $TEMPLATE_ID) created successfully."
echo "Terraform can now clone from this template."