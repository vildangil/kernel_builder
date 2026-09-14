#!/bin/bash
# Prepare android_kernel_m168 before compilation.
# Run from the kernel source directory.

set -euxo pipefail

export ROOT_SOLUTION="${ROOT_SOLUTION:-ReSukiSU}"
export BUILD_FILESYSTEM="${BUILD_FILESYSTEM:-EROFS}"
export CM4_WATCHDOG_OFF="${CM4_WATCHDOG_OFF:-false}"
export PERMISSIVE="${PERMISSIVE:-false}"

rm -rf KernelSU KernelSU-Next
rm -f drivers/kernelsu

case "$ROOT_SOLUTION" in
  KernelSU-Next)
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/legacy/kernel/setup.sh" | bash -s legacy
    ;;
  ReSukiSU)
    curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
    ;;
  *)
    echo "Unsupported root solution: $ROOT_SOLUTION" >&2
    exit 2
    ;;
esac

readlink -f drivers/kernelsu
test -f drivers/kernelsu/Kconfig

if [ "$CM4_WATCHDOG_OFF" = "true" ]; then
  python3 - <<'PY'
from pathlib import Path

path = Path('drivers/watchdog/sprd_pmic_wdt.c')
text = path.read_text()
start = text.find('static bool sprd_pimc_wdt_en(void)')
end = text.find('static const struct of_device_id', start)
if start < 0 or end < 0:
    raise SystemExit(f'Could not locate sprd_pimc_wdt_en() in {path}')
block = text[start:end]
old = '\treturn true;'
new = '\treturn false; /* diagnostic: disable PM_SYS/CM4 watchdog */'
if old not in block:
    raise SystemExit('Expected final return true in sprd_pimc_wdt_en() not found')
block = block.replace(old, new, 1)
path.write_text(text[:start] + block + text[end:])
PY
  echo "===== CM4 watchdog diagnostic patch ====="
  sed -n '/static bool sprd_pimc_wdt_en/,/static const struct of_device_id/p' drivers/watchdog/sprd_pmic_wdt.c | tail -n 25
fi

if [ "$PERMISSIVE" = "true" ]; then
  git fetch --depth 1 origin KernelSU-permissive
  git checkout FETCH_HEAD -- security/selinux/hooks.c security/selinux/selinuxfs.c
  echo "SELinux permissive patch applied from KernelSU-permissive"
fi

echo "A03 Core source preparation complete"
echo "root=$ROOT_SOLUTION filesystem=$BUILD_FILESYSTEM cm4_off=$CM4_WATCHDOG_OFF permissive=$PERMISSIVE"
