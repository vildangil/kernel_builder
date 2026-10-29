#!/usr/bin/env bash
# Install BakaSU in the current kernel tree (not the builder checkout).
set -euo pipefail
[[ -d drivers && -f Makefile ]] || { echo "Run from the kernel source root" >&2; exit 2; }
setup_script="$(mktemp)"
trap 'rm -f "$setup_script"' EXIT
curl --fail --location --silent --show-error --retry 3 \
  https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh \
  --output "$setup_script"
# The upstream setup script silently falls back to main when checkout
# fails. Verify the exact requested ref so that CI can't ship a mismatched BakaSU.
# sync-susfs no longer exists upstream; use main unless KSU_REF is set.
ref="${KSU_REF:-main}"
sh "$setup_script" "$ref"
[[ -d KernelSU/.git ]] || { echo "Missing BakaSU checkout" >&2; exit 1; }
expected="$(git -C KernelSU rev-parse --verify "${ref}^{commit}")" || {
  echo "BakaSU requested ref '${ref}' not available" >&2; exit 1;
}
actual="$(git -C KernelSU rev-parse HEAD)"
[[ "$expected" == "$actual" ]] || {
  echo "BakaSU checkout mismatch: expected $expected, got $actual" >&2; exit 1;
}
[[ -f KernelSU/kernel/Kconfig && -e drivers/kernelsu/Kconfig ]] || {
  echo "BakaSU integration is incomplete: missing KernelSU/kernel/Kconfig" >&2
  exit 1
}
echo "BakaSU source: $ref @ $actual"
