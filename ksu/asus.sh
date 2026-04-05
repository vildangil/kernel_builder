#!/bin/bash

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v2.1.0
git add . && git commit -am "drivers: SukiSU Ultra + SusFS"

patchesdir="$outside/ksu/patches/"
suspatchesdir="$outside/ksu/sus_patches/"

if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu susfs failed, the kernel version you want to patch doesnt have patches here yet"
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
echo 'CONFIG_KSU_SUSFS=y' >> "${defconfig_file}"
echo 'CONFIG_SUSFS=y' >> "${defconfig_file}"
echo 'CONFIG_SUSFS_VERSION="v2.1.0"' >> "${defconfig_file}"
