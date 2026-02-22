#!/usr/bin/env bash
#
# Create a Proxmox cloud-init template from an Ubuntu cloud image.
# Run this script on the Proxmox host or from a machine with API/shell access.
#
# Parity with docs/my-old-notes.md: VM create, import disk, scsi0, resize (optional),
# cloud-init drive, boot order, serial/VGA for console, optional ciuser/cipassword/
# ipconfig0/sshkeys, then qm template. Terraform injects sshkeys/ipconfig per clone.
#
set -euo pipefail

# --- Configuration ---
# VMID must be set explicitly (e.g. 900 for templates) so we don't overwrite an existing VM/template.
# Pass as first argument or set VMID in the environment: ./create-ubuntu-template.sh 900  or  VMID=900 ./create-ubuntu-template.sh
VMID="${1:-${VMID:-}}"
if [[ -z "${VMID}" || ! "${VMID}" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <VMID>" >&2
  echo "  VMID must be set explicitly (e.g. 900 for templates) to avoid overwriting an existing VM." >&2
  echo "  Example: $0 900" >&2
  exit 1
fi

TEMPLATE_NAME="${TEMPLATE_NAME:-ubuntu-cloud}"
STORAGE="${STORAGE:-local-lvm}"
# Ubuntu release: jammy (22.04) or noble (24.04)
UBUNTU_RELEASE="${UBUNTU_RELEASE:-jammy}"
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-amd64.img"
IMAGE_NAME="${UBUNTU_RELEASE}-server-cloudimg-amd64.img"

# Optional: resize template disk (e.g. +20G). Clones can still override size via Terraform.
TEMPLATE_DISK_RESIZE="${TEMPLATE_DISK_RESIZE:-}"

# Optional: cloud-init defaults on the template (for UI clones or fallbacks). Terraform sets these per clone.
# Set CIUSER, CIPASSWORD, SSH_PUBLIC_KEY_PATH (path on Proxmox host) if you want template-level defaults.
IPCONFIG0="${IPCONFIG0:-ip=dhcp}"

# Template VM resources (minimal by default; clones get their own via Terraform)
MEMORY="${MEMORY:-1024}"
CORES="${CORES:-1}"

# --- Step 1: Download Ubuntu cloud image (if not already present) ---
# Cloud images are minimal and prepared for cloud-init (no cloud-init package needed on host).
if [[ -f "$IMAGE_NAME" ]]; then
  echo "Using existing image: $IMAGE_NAME (delete it to re-download)"
else
  echo "Downloading Ubuntu ${UBUNTU_RELEASE} cloud image..."
  wget -q --show-progress -O "$IMAGE_NAME" "$UBUNTU_IMAGE_URL"
fi

# --- Step 2: Create VM with the given VMID ---
echo "Creating VM ${VMID}..."
qm create "$VMID" --name "$TEMPLATE_NAME" --memory "$MEMORY" --cores "$CORES" --net0 virtio,bridge=vmbr0

# --- Step 3: Import the cloud image as a disk ---
# Import the downloaded image into Proxmox storage. This becomes the primary disk.
echo "Importing disk into storage ${STORAGE}..."
qm importdisk "$VMID" "$IMAGE_NAME" "$STORAGE"

# --- Step 4: Attach the imported disk and set as SCSI 0 ---
# The import creates an unused disk; we attach it as scsi0 for normal boot.
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${VMID}-disk-0"

# --- Step 4b: Optionally resize the template disk (e.g. TEMPLATE_DISK_RESIZE=+20G) ---
if [[ -n "${TEMPLATE_DISK_RESIZE}" ]]; then
  echo "Resizing disk: scsi0 ${TEMPLATE_DISK_RESIZE}..."
  qm resize "$VMID" scsi0 "$TEMPLATE_DISK_RESIZE"
fi

# --- Step 5: Add cloud-init drive ---
# Cloud-init drive holds user, SSH keys, and network config when cloning from template.
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"

# --- Step 6: Set boot order and serial/VGA (for console-based management) ---
# Boot from the main disk (scsi0). Serial + VGA to serial help with Proxmox console.
qm set "$VMID" --boot order=scsi0 --serial0 socket --vga serial0

# --- Step 7: Optional cloud-init defaults on template (Terraform overrides these per clone) ---
qm set "$VMID" --ipconfig0 "$IPCONFIG0"
if [[ -n "${CIUSER:-}" ]]; then qm set "$VMID" --ciuser "$CIUSER"; fi
if [[ -n "${CIPASSWORD:-}" ]]; then qm set "$VMID" --cipassword "$CIPASSWORD"; fi
if [[ -n "${SSH_PUBLIC_KEY_PATH:-}" && -f "${SSH_PUBLIC_KEY_PATH}" ]]; then
  qm set "$VMID" --sshkey "$SSH_PUBLIC_KEY_PATH"
fi

# --- Step 8: Convert VM to template ---
# Templates cannot be started; they are only used for cloning (e.g. by Terraform).
qm template "$VMID"

echo "Done. Template '$TEMPLATE_NAME' (VMID $VMID) is ready for Terraform clones."
echo "Optional: install qemu-guest-agent in each clone after first boot (or via Ansible) for IP reporting."
# Clean up local image if desired: rm -f "$IMAGE_NAME"
