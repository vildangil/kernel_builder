#!/usr/bin/env bash
# Enable namespace/cgroup/container requirements on Rosemary non-GKI 4.14.
set -euo pipefail
outside="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f Makefile && -f scripts/config ]] || { echo "Run in kernel source directory" >&2; exit 2; }
source "$outside/env"
[[ -f "$defconfig_file" ]] || { echo "Missing defconfig: $defconfig_file" >&2; exit 2; }
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    CONFIG_*=y)
      key="${line%%=*}"
      bash scripts/config --file "$defconfig_file" -e "${key#CONFIG_}"
      ;;
    CONFIG_*=n)
      key="${line%%=*}"
      bash scripts/config --file "$defconfig_file" -d "${key#CONFIG_}"
      ;;
  esac
done < "$outside/configs/droidspaces-4.14.config"
# Compatibility fix from DroidSpaces' non-GKI patch 02, adapted to
# Rosemary's cgroup_add_file() variant with css as its first parameter.
git apply --check "$outside/configs/droidspaces-cgroup-4.14.patch"
git apply "$outside/configs/droidspaces-cgroup-4.14.patch"
