#!/usr/bin/env bash
set -euo pipefail
outside="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# These Rosemary-specific patches are NOT upstream and must apply cleanly.
for patch_file in \
  "$outside/ksu/hooks/test_resukisu_hooks.patch" \
  "$outside/ksu/hooks/test-patch-to-fix-fallback.patch"; do
  echo "Checking: $patch_file"
  git apply --check "$patch_file"
  git apply "$patch_file"
done
