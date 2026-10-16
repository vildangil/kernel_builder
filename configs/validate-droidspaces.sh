#!/usr/bin/env bash
set -euo pipefail
config="${1:-out/.config}"
[[ -f "$config" ]] || { echo "DroidSpaces: missing generated config $config" >&2; exit 1; }
# Essential features, not the complete optional feature list.
mandatory=(SYSVIPC POSIX_MQUEUE NAMESPACES PID_NS UTS_NS IPC_NS
  USER_NS SECCOMP SECCOMP_FILTER CGROUPS CGROUP_DEVICE
  DEVTMPFS NET_NS VETH BRIDGE)
bad=0
for opt in "${mandatory[@]}"; do
  if ! grep -qx "CONFIG_${opt}=y" "$config"; then
    echo "::error::DroidSpaces requires CONFIG_${opt}=y (not enabled in $config)" >&2
    bad=1
  fi
done
exit "$bad"
