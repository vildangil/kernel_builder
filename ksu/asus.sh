#!/bin/bash
#
# hdjsjfjjwufbeizihfjejzf

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/xxblebleblexx/MultiSU/refs/heads/legacy/kernel/setup.sh" | bash -s legacy_susfs

git add . && git commit -am "drivers: KernelSU-Next + SuSFS"
KSU_git_ver=$(cd KernelSU-Next && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 30000))

patchesdir="$outside/ksu/patches/"
suspatchesdir="$outside/ksu/sus_patches/"

CONFIG_KSU=y
# CONFIG_KPROBES is not set
# CONFIG_KPROBE_EVENTS is not set
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
# CONFIG_HAVE_KPROBES is not set
# CONFIG_KALLSYMS_BASE_RELATIVE is not set
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_SU=y

if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am --3way "$patch_file" || git apply "$patch_file" --ignore-whitespace --ignore-space-change || true
  done
else
  echo "ERROR: KSU patches not found"
  exit 1
fi

if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am --3way "$patch_file" || git apply "$patch_file" --ignore-whitespace --ignore-space-change || true
  done
else
  echo "ERROR: SuSFS patches not found"
  exit 1
fi

if [ ! -f "include/linux/susfs.h" ]; then
    echo "WARNING: susfs.h not found! Trying to find and copy manually..."
    # Ищем файл в репозитории MultiSU или в патчах
    find . -name "susfs.h" -exec cp {} include/linux/ \;
fi

if [ ! -f "include/linux/susfs_def.h" ]; then
    echo "WARNING: susfs_def.h not found! Trying to find and copy manually..."
    find . -name "susfs_def.h" -exec cp {} include/linux/ \;
fi

if ! grep -q "susfs.h" fs/namespace.c; then
    echo "WARNING: susfs.h not included in namespace.c, adding..."
    sed -i '/#include <linux\/fs.h>/a #include <linux\/susfs.h>' fs/namespace.c
fi

grep -r "ksu_syscall\|susfs" . &>/dev/null && echo "Hooks found!" || echo "WARNING: Hooks not found!"

sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-BlacksideKernel-ksus-Fckssom\"/" "${defconfig_file}"

echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"

echo -e " \nincludes MultiSU, ver ${KSU_ver}" >> banner_append
echo -e " \nincludes SuSFS v2.1.0" >> banner_append
