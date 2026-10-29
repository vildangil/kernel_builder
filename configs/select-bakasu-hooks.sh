#!/usr/bin/env bash
# Keep the requested BakaSU hook mode unambiguous on non-GKI rosemary.
# BakaSU defines MANUAL_HOOK and SUSFS as mutually exclusive Kconfig choice.
set -euo pipefail
[[ $# -eq 1 ]] || { echo "Usage: $0 <susfs|manual>" >&2; exit 2; }
config=arch/arm64/configs/rosemary_defconfig
[[ -f "$config" && -f KernelSU/kernel/Kconfig ]] || {
  echo "Run from the kernel source root after BakaSU setup" >&2; exit 2;
}
sed -i '/^CONFIG_KSU_TRACEPOINT_HOOK=/d; /^# CONFIG_KSU_TRACEPOINT_HOOK is not set$/d' "$config"
case "$1" in
  susfs)
    sed -i '/^CONFIG_KSU_MANUAL_HOOK=/d; /^# CONFIG_KSU_MANUAL_HOOK is not set$/d' "$config"
    # Remove mode-specific stale settings: these are valid only in manual mode.
    sed -i '/^CONFIG_KSU_MANUAL_HOOK_AUTO_/d; /^# CONFIG_KSU_MANUAL_HOOK_AUTO_.* is not set$/d' "$config"
    sed -i '/^CONFIG_KSU_SUSFS=/d; /^# CONFIG_KSU_SUSFS is not set$/d' "$config"
    printf '\nCONFIG_KSU_SUSFS=y\n' >> "$config"
    expected=KSU_SUSFS
    ;;
  manual)
    sed -i '/^CONFIG_KSU_SUSFS=/d; /^# CONFIG_KSU_SUSFS is not set$/d' "$config"
    sed -i '/^CONFIG_KSU_MANUAL_HOOK=/d; /^# CONFIG_KSU_MANUAL_HOOK is not set$/d' "$config"
    printf '\nCONFIG_KSU_MANUAL_HOOK=y\n' >> "$config"
    expected=KSU_MANUAL_HOOK
    ;;
  *)
    echo "Unknown BakaSU mode: $1" >&2; exit 2 ;;
esac
grep -qx 'CONFIG_KSU=y' "$config" || {
  echo "CONFIG_KSU=y is missing from $config" >&2; exit 1;
}
echo "Requested BakaSU hook mode: $expected (must be verified after olddefconfig)"
