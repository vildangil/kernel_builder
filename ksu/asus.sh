#!/bin/bash

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

git am --abort >/dev/null 2>&1
git reset --hard HEAD

curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v2.1.0 >/dev/null 2>&1
sed -i '/MODULE_IMPORT_NS/d' drivers/kernelsu/core/init.c 2>/dev/null
git add . && git commit -am "update" --quiet

cat <<EOF > drivers/kernelsu/ksu_fix.h
#ifndef KSU_FIX_H
#define KSU_FIX_H
#include <linux/fs.h>
#include <linux/path.h>
struct file;
int ksu_handle_fops(struct file *file);
void ksu_dentry_init(void);
#endif
EOF

sed -i '1i #include "ksu_fix.h"' drivers/kernelsu/ksu.c
sed -i '1i #include "ksu_fix.h"' drivers/kernelsu/init.c
sed -i '1i #include <linux/sched.h>\n#include <linux/file.h>\n#include <linux/version.h>' drivers/kernelsu/init.c

sed -i 's/static int ksu_handle_fops/int ksu_handle_fops/g' drivers/kernelsu/ksu.c 2>/dev/null
sed -i 's/static void ksu_dentry_init/void ksu_dentry_init/g' drivers/kernelsu/init.c 2>/dev/null

git add . && git commit -m "fixup" --quiet

patchesdir="$outside/ksu/patches/"
suspatchesdir="$outside/ksu/sus_patches/"

if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file" --quiet >/dev/null 2>&1 || git am --skip
  done
fi

if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file" --quiet >/dev/null 2>&1 || git am --skip
  done
fi

sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
fi

sed -i '/CONFIG_KSU/d' "${defconfig_file}"
sed -i '/CONFIG_SUSFS/d' "${defconfig_file}"

{
  echo 'CONFIG_KPROBES=y'
  echo 'CONFIG_KPROBE_EVENTS=y'
  echo 'CONFIG_OVERLAY_FS=y'
  echo 'CONFIG_KSU=y'
  echo 'CONFIG_KSU_SUSFS=y'
  echo 'CONFIG_SUSFS=y'
  echo 'CONFIG_SUSFS_VERSION="v2.1.0"'
} >> "${defconfig_file}"

git add .
git commit -m "update config" --quiet
