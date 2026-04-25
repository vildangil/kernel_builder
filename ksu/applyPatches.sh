#!/bin/bash

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -
sed -i '/MODULE_IMPORT_NS/d' drivers/kernelsu/core/init.c 2>/dev/null
sed -i 's|#include <linux/pgtable.h>|#include <asm/pgtable.h>|g' drivers/kernelsu/feature/sucompat.c
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

# Очищаем старые записи, чтобы не было дублей
sed -i '/CONFIG_KSU/d' "${defconfig_file}"

{
  echo 'CONFIG_KPROBES=y'
  echo 'CONFIG_KPROBE_EVENTS=y'
  echo 'CONFIG_OVERLAY_FS=y'
  echo 'CONFIG_KSU=y'
} >> "${defconfig_file}"

git add .
git commit -m "update config" --quiet
