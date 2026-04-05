#!/bin/bash
#
# hdjsjfjjwufbeizihfjejzf

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -
git add . && git commit -am "drivers: KernelSU"
KSU_git_ver=$(cd KernelSU-Next && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 30000))

echo 'CONFIG_KSU_EXTRAS=y' >> "${defconfig_file}"
patchesdir="$outside/ksu/patches/"
if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}\"/" "${defconfig_file}"

echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"

