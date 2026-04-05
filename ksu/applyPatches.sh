#!/bin/bash

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -
git add . && git commit -am "drivers: SukiSU Ultra"

patchesdir="$outside/ksu/patches/"
if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
fi

echo 'CONFIG_KPROBES=y' >> "${defconfig_file}"
echo 'CONFIG_KPROBE_EVENTS=y' >> "${defconfig_file}"
echo 'CONFIG_OVERLAY_FS=y' >> "${defconfig_file}"
echo 'CONFIG_KSU=y' >> "${defconfig_file}"
