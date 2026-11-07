#!/usr/bin/env bash
# Smoke-tests template 901 on hogwarts: full-clones it twice, injects identity via cloud-init (as Terraform does),
# checks the node setup and clone uniqueness, then destroys the clones. Usage: ./scripts/verify-k3s-template.sh [TEMPLATE_ID]
set -uo pipefail

PVE=root@192.168.4.196
TPL=${1:-901}
IDS=(9998 9999); IPS=(192.168.6.251 192.168.6.252)   # temp test IPs, static space (docs/NETWORK.md)
PUB=${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
fail=0

cleanup() { for id in "${IDS[@]}"; do ssh "$PVE" "qm stop $id --skiplock 1; qm destroy $id --purge 1" >/dev/null 2>&1; done; }
trap cleanup EXIT
cleanup

scp -q "${SSH_OPTS[@]}" "$PUB" "$PVE:/tmp/verify.pub"
for i in 0 1; do
  ssh "$PVE" "qm clone $TPL ${IDS[$i]} --name verify-${IDS[$i]} --full 1 >/dev/null &&
    qm set ${IDS[$i]} --ciuser firebolt --sshkeys /tmp/verify.pub --ipconfig0 ip=${IPS[$i]}/22,gw=192.168.4.1 >/dev/null &&
    qm start ${IDS[$i]}" || { echo "clone/start failed"; exit 1; }
done

check() { # name, command, expected (grep -E pattern) per host
  local ip=$1 name=$2 cmd=$3 want=$4 out
  out=$(ssh "${SSH_OPTS[@]}" "firebolt@$ip" "$cmd" 2>&1)
  if grep -qE "$want" <<<"$out"; then echo "PASS $ip $name"; else echo "FAIL $ip $name (got: $(tr '\n' ' ' <<<"$out" | cut -c1-120))"; fail=1; fi
}

declare -A mid hk
for i in 0 1; do
  ip=${IPS[$i]}
  for _ in $(seq 30); do ssh "${SSH_OPTS[@]}" "firebolt@$ip" true 2>/dev/null && break; sleep 5; done
  check "$ip" "ssh + key from cloud-init" "sudo -n true && echo ok" "^ok$"
  check "$ip" "timezone"          "timedatectl show -p Timezone --value" "^America/Chicago$"
  check "$ip" "no ipv6 addresses" "ip -6 addr | grep -c inet6" "^0$"
  check "$ip" "ipv6.disable=1"    "grep -o ipv6.disable=1 /proc/cmdline" "ipv6.disable=1"
  check "$ip" "k3s kernel mods"   "lsmod | grep -cE '^(br_netfilter|overlay)'" "^2$"
  check "$ip" "ip_forward"        "sysctl -n net.ipv4.ip_forward" "^1$"
  check "$ip" "no swap"           "swapon --show | wc -l" "^0$"
  check "$ip" "agent + iscsid"    "systemctl is-active qemu-guest-agent iscsid | tr '\n' ' '" "^active active "
  check "$ip" "multipathd masked" "systemctl is-enabled multipathd 2>&1" "masked"
  check "$ip" "nfs/iscsi tools"   "which mount.nfs iscsiadm | wc -l" "^2$"
  check "$ip" "no failed units"   "systemctl --failed --no-legend | wc -l" "^0$"
  mid[$i]=$(ssh "${SSH_OPTS[@]}" "firebolt@$ip" 'cat /etc/machine-id')
  hk[$i]=$(ssh "${SSH_OPTS[@]}" "firebolt@$ip" 'sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | cut -d" " -f2')
done
[ -n "${mid[0]}" ] && [ "${mid[0]}" != "${mid[1]}" ] && echo "PASS unique machine-id" || { echo "FAIL machine-id not unique"; fail=1; }
[ -n "${hk[0]}" ] && [ "${hk[0]}" != "${hk[1]}" ] && echo "PASS unique ssh host keys" || { echo "FAIL ssh host keys not unique"; fail=1; }
ssh "$PVE" "qm agent ${IDS[0]} ping" >/dev/null 2>&1 && echo "PASS guest agent ping" || { echo "FAIL guest agent ping"; fail=1; }

[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
