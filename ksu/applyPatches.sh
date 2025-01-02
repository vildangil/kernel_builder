#!/bin/bash
#
# hdjsjfjjwufbeizihfjejzf

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/magic/kernel/setup.sh" | bash -
git add . && git commit -am "drivers: KernelSU"
KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 10000 + 200))

short_k_ver="$(echo $kernel_ver | cut -d. -f1,2)"

patchesdir="$outside/ksu/patches"
kpatchesdir="$patchesdir/$short_k_ver"
susdir="$outside/ksu/susfs/kernel_patches"

if [[ -d "$kpatchesdir" ]]; then
  for patch_file in "$kpatchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

if [[ "$short_k_ver" == "4.19" ]] ; then
  cp "$susdir/fs/susfs.c" ./fs
  cp "$susdir/include/linux/susfs.h" ./include/linux
  cd KernelSU && git am "$patchesdir"/KernelSU/0001-sussy-baka-xx-gaming.patch && cd ..
fi

sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-ks${KSU_ver}\"/" "${defconfig_file}"

echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"

echo -e " \nincludes KernelSU ${KSU_ver}" >> banner_append

