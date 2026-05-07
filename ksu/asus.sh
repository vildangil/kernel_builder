#!/bin/bash

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/xxblebleblexx/MultiSU/refs/heads/legacy/kernel/setup.sh" | bash -s legacy_susfs

git add . && git commit -am "drivers: KernelSU-Next + SuSFS"
KSU_git_ver=$(cd KernelSU-Next && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 30000))

patchesdir="$outside/ksu/patches/"
suspatchesdir="$outside/ksu/sus_patches/"

echo 'CONFIG_KSU=y' >> "${defconfig_file}"
echo 'CONFIG_KSU_EXTRAS=y' >> "${defconfig_file}"
echo 'CONFIG_KSU_MANUAL_HOOK=y' >> "${defconfig_file}"
echo '# CONFIG_KPROBES is not set' >> "${defconfig_file}"
echo '# CONFIG_KPROBES_QGKI is not set' >> "${defconfig_file}"
echo '# CONFIG_KSU_SUSFS_TRY_UMOUNT is not set' >> "${defconfig_file}"
echo 'CONFIG_KSU_SUSFS=y' >> "${defconfig_file}"

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

sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-ksus-Fckssom\"/" "${defconfig_file}"

echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"

echo -e " \nincludes MultiSU, ver ${KSU_ver}" >> banner_append
echo -e " \nincludes SuSFS v2.1.0" >> banner_append