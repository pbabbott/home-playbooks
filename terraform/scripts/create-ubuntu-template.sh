#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  PROXMOX_SSH_HOST
  PROXMOX_SSH_USER
  PROXMOX_SSH_PORT
  UBUNTU_TEMPLATE_VMID
  UBUNTU_TEMPLATE_NAME
  UBUNTU_TEMPLATE_STORAGE
  UBUNTU_TEMPLATE_UBUNTU_RELEASE
  UBUNTU_TEMPLATE_MEMORY
  UBUNTU_TEMPLATE_CORES
  UBUNTU_TEMPLATE_BRIDGE
  UBUNTU_TEMPLATE_IPCONFIG0
  UBUNTU_TEMPLATE_WORK_DIR
)

for required_var in "${required_vars[@]}"; do
  if [[ -z "${!required_var:-}" ]]; then
    echo "Missing required environment variable: ${required_var}" >&2
    exit 1
  fi
done

if ! [[ "${UBUNTU_TEMPLATE_VMID}" =~ ^[0-9]+$ ]]; then
  echo "UBUNTU_TEMPLATE_VMID must be a positive integer." >&2
  exit 1
fi

expand_home_path() {
  local input_path="$1"
  case "${input_path}" in
    "~")
      printf "%s\n" "${HOME}"
      ;;
    "~/"*)
      printf "%s\n" "${HOME}/${input_path#~/}"
      ;;
    *)
      printf "%s\n" "${input_path}"
      ;;
  esac
}

local_public_key_path=""
if [[ -n "${UBUNTU_TEMPLATE_SSH_PUBLIC_KEY_PATH:-}" ]]; then
  local_public_key_path="$(expand_home_path "${UBUNTU_TEMPLATE_SSH_PUBLIC_KEY_PATH}")"
  if [[ ! -f "${local_public_key_path}" ]]; then
    echo "SSH public key file not found: ${local_public_key_path}" >&2
    exit 1
  fi
fi

ssh_private_key_path=""
if [[ -n "${PROXMOX_SSH_PRIVATE_KEY_PATH:-}" ]]; then
  ssh_private_key_path="$(expand_home_path "${PROXMOX_SSH_PRIVATE_KEY_PATH}")"
  if [[ ! -f "${ssh_private_key_path}" ]]; then
    echo "SSH private key file not found: ${ssh_private_key_path}" >&2
    exit 1
  fi
fi

ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "${PROXMOX_SSH_PORT}")
scp_cmd=(scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -P "${PROXMOX_SSH_PORT}")

if [[ -n "${ssh_private_key_path}" ]]; then
  ssh_cmd+=(-i "${ssh_private_key_path}")
  scp_cmd+=(-i "${ssh_private_key_path}")
fi

remote_target="${PROXMOX_SSH_USER}@${PROXMOX_SSH_HOST}"
image_name="${UBUNTU_TEMPLATE_UBUNTU_RELEASE}-server-cloudimg-amd64.img"
image_url="https://cloud-images.ubuntu.com/${UBUNTU_TEMPLATE_UBUNTU_RELEASE}/current/${image_name}"
remote_ssh_key_path=""

if [[ -n "${local_public_key_path}" ]]; then
  remote_ssh_key_path="${UBUNTU_TEMPLATE_WORK_DIR}/.sshkey-${UBUNTU_TEMPLATE_VMID}.pub"
  work_dir_escaped="$(printf "%q" "${UBUNTU_TEMPLATE_WORK_DIR}")"
  "${ssh_cmd[@]}" "${remote_target}" "mkdir -p ${work_dir_escaped}"
  "${scp_cmd[@]}" "${local_public_key_path}" "${remote_target}:${remote_ssh_key_path}"
fi

quote_for_remote() {
  printf "%q" "$1"
}

remote_env=(
  "VMID=$(quote_for_remote "${UBUNTU_TEMPLATE_VMID}")"
  "TEMPLATE_NAME=$(quote_for_remote "${UBUNTU_TEMPLATE_NAME}")"
  "STORAGE=$(quote_for_remote "${UBUNTU_TEMPLATE_STORAGE}")"
  "WORK_DIR=$(quote_for_remote "${UBUNTU_TEMPLATE_WORK_DIR}")"
  "IMAGE_NAME=$(quote_for_remote "${image_name}")"
  "IMAGE_URL=$(quote_for_remote "${image_url}")"
  "DISK_RESIZE=$(quote_for_remote "${UBUNTU_TEMPLATE_DISK_RESIZE:-}")"
  "MEMORY=$(quote_for_remote "${UBUNTU_TEMPLATE_MEMORY}")"
  "CORES=$(quote_for_remote "${UBUNTU_TEMPLATE_CORES}")"
  "BRIDGE=$(quote_for_remote "${UBUNTU_TEMPLATE_BRIDGE}")"
  "IPCONFIG0=$(quote_for_remote "${UBUNTU_TEMPLATE_IPCONFIG0}")"
  "CIUSER=$(quote_for_remote "${UBUNTU_TEMPLATE_CIUSER:-}")"
  "CIPASSWORD=$(quote_for_remote "${UBUNTU_TEMPLATE_CIPASSWORD:-}")"
  "SSH_KEY_PATH=$(quote_for_remote "${remote_ssh_key_path}")"
)

"${ssh_cmd[@]}" "${remote_target}" "${remote_env[*]} bash -se" <<'REMOTE_SCRIPT'
set -euo pipefail

if qm status "${VMID}" >/dev/null 2>&1; then
  qm stop "${VMID}" >/dev/null 2>&1 || true
  qm destroy "${VMID}" --purge 1
fi

mkdir -p "${WORK_DIR}"
if [[ ! -f "${WORK_DIR}/${IMAGE_NAME}" ]]; then
  wget -q -O "${WORK_DIR}/${IMAGE_NAME}" "${IMAGE_URL}"
fi

qm create "${VMID}" \
  --name "${TEMPLATE_NAME}" \
  --memory "${MEMORY}" \
  --cores "${CORES}" \
  --net0 "virtio,bridge=${BRIDGE}"

qm importdisk "${VMID}" "${WORK_DIR}/${IMAGE_NAME}" "${STORAGE}"
qm set "${VMID}" --scsihw virtio-scsi-pci --scsi0 "${STORAGE}:vm-${VMID}-disk-0"

if [[ -n "${DISK_RESIZE}" ]]; then
  qm resize "${VMID}" scsi0 "${DISK_RESIZE}"
fi

qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"
qm set "${VMID}" --boot "order=scsi0" --serial0 socket --vga serial0
qm set "${VMID}" --ipconfig0 "${IPCONFIG0}"

if [[ -n "${CIUSER}" ]]; then
  qm set "${VMID}" --ciuser "${CIUSER}"
fi

if [[ -n "${CIPASSWORD}" ]]; then
  qm set "${VMID}" --cipassword "${CIPASSWORD}"
fi

if [[ -n "${SSH_KEY_PATH}" ]]; then
  qm set "${VMID}" --sshkey "${SSH_KEY_PATH}"
fi

qm template "${VMID}"
REMOTE_SCRIPT

echo "Template '${UBUNTU_TEMPLATE_NAME}' (VMID ${UBUNTU_TEMPLATE_VMID}) is ready."
