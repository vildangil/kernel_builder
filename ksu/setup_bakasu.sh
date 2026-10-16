#!/usr/bin/env bash
# Install BakaSU in the current kernel tree (not the builder checkout).
set -euo pipefail
[[ -d drivers && -f Makefile ]] || { echo "Run from the kernel source root" >&2; exit 2; }
setup_script="$(mktemp)"
trap 'rm -f "$setup_script"' EXIT
curl --fail --location --silent --show-error --retry 3 \
  https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh \
  --output "$setup_script"
# Pin a tag or commit by setting KSU_REF. Main is the current BakaSU branch.
sh "$setup_script" "${KSU_REF:-main}"
[[ -f KernelSU/kernel/Kconfig && -e drivers/kernelsu/Kconfig ]] || {
  echo "BakaSU integration is incomplete: missing KernelSU/kernel/Kconfig" >&2
  exit 1
}
echo "BakaSU source: $(git -C KernelSU rev-parse --short HEAD)"
