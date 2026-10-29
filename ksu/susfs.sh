#!/usr/bin/env bash
set -euo pipefail
outside="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$outside/ksu/setup_bakasu.sh"
bash "$outside/configs/select-bakasu-hooks.sh" susfs
# Apply one SUSFS port only. The previous wildcard also applied an
# incompatible legacy port and silently continued after .rej files.
susfs_patch="${SUSFS_PATCH:-$outside/ksu/sus/test-susfs.patch}"
[[ -f "$susfs_patch" ]] || { echo "Missing SUSFS patch: $susfs_patch" >&2; exit 2; }
echo "Checking SUSFS port: $susfs_patch"
# The shadow procfs layout has three diverged files. Apply the exact
# patch to every other file, then port those files with checked substitutions.
susfs_excludes=(
  --exclude=fs/notify/fdinfo.c
  --exclude=fs/proc/task_mmu.c
  --exclude=mm/memory.c
)
if ! git apply --check "${susfs_excludes[@]}" "$susfs_patch"; then
  echo "SUSFS 2.3.0 port does not apply to this 4.14.186 kernel." >&2
  echo "Adapt the rejected hunks against the shadow source before compiling." >&2
  exit 1
fi
git apply "${susfs_excludes[@]}" "$susfs_patch"
python3 "$outside/ksu/sus/port_shadow_susfs.py" "$susfs_patch"
bash "$outside/ksu/apply_hooks.sh"
# Older 4.14 stat/faccessat syscalls take userspace path pointers rather than
# struct filename **. Activate matching hooks in SUSFS mode for su detection.
python3 "$outside/ksu/hooks/port_bakasu_sucompat_414.py"
version="$(git -C KernelSU rev-parse --short HEAD)"
printf '\nIncludes BakaSU (%s) + SUSFS (4.14 port)\n' "$version" >> banner_append
