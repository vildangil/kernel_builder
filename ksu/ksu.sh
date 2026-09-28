#!/bin/bash
#
# ReSukiSU (Non-SuSFS)

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/White-Society/WhiteSU/dev/kernel/setup.sh" | bash -s legacy
git add . && git commit -am "drivers: KernelSU"
KSU_git_ver=$(cd WhiteSU && git rev-list --count HEAD)
KSU_ver=$KSU_git_ver

patchesdir="$outside/ksu/hooks/"

if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    patch -p1 < "$patch_file"
  done
else
  echo "patching ksu failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-ksu${KSU_ver}\"/" "${defconfig_file}"
echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"
echo -e " \nincludes WhiteSU, ver ${KSU_ver}" >> banner_append
echo -e " \nincludes NoMount v2.0.0" >> banner_append
