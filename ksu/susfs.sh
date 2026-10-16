#!/usr/bin/env bash
set -euo pipefail
outside="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$outside/ksu/setup_bakasu.sh"
# Apply one SUSFS port only. The previous wildcard also applied an
# incompatible legacy port and silently continued after .rej files.
susfs_patch="${SUSFS_PATCH:-$outside/ksu/sus/test-susfs.patch}"
[[ -f "$susfs_patch" ]] || { echo "Missing SUSFS patch: $susfs_patch" >&2; exit 2; }
echo "Checking SUSFS port: $susfs_patch"
if ! git apply --check "$susfs_patch"; then
  echo "SUSFS 2.3.0 port does not apply to this 4.14.186 kernel." >&2
  echo "Adapt the rejected hunks against the shadow source before compiling." >&2
  exit 1
fi
git apply "$susfs_patch"
bash "$outside/ksu/apply_hooks.sh"
version="$(git -C KernelSU rev-parse --short HEAD)"
printf '\nIncludes BakaSU (%s) + SUSFS (4.14 port)\n' "$version" >> banner_append
