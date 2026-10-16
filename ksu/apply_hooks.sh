#!/usr/bin/env bash
set -euo pipefail
outside="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The SUSFS 2.3.0 stat hook modifies the same source file as BakaSU's
# manual syscall hooks. Apply the non-overlapping files with git apply,
# then merge fs/stat.c via source-checked substitutions.
manual="$outside/ksu/hooks/test_resukisu_hooks.patch"
fingerprint="$outside/ksu/hooks/test-patch-to-fix-fallback.patch"

echo "Checking BakaSU manual hooks outside fs/stat.c"
git apply --check --exclude=fs/stat.c "$manual"
git apply --exclude=fs/stat.c "$manual"
python3 "$outside/ksu/hooks/port_shadow_stat_hooks.py" "$manual"

echo "Checking fingerprint fallback patch"
git apply --check "$fingerprint"
git apply "$fingerprint"
