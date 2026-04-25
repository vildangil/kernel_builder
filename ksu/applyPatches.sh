#!/bin/bash
#
# hdjsjfjjwufbeizihfjejzf

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/master/kernel/setup.sh" | bash -s master
sed -i 's/#define KSU_EXPECTED_SIZE .*/#define KSU_EXPECTED_SIZE 0/' drivers/kernelsu/core/manager.h
sed -i 's/#define KSU_EXPECTED_HASH .*/#define KSU_EXPECTED_HASH ""/' drivers/kernelsu/core/manager.h
git add . && git commit -am "drivers: KernelSU"
KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 30000))

patchesdir="$outside/ksu/patches/"
if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-SUSFS\"/" "${defconfig_file}"

echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"

echo -e " \nincludes KernelSU, ver ${KSU_ver}" >> banner_append

