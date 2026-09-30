#!/bin/bash
#
# ReSukiSU (Non-SuSFS)

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
git add . && git commit -am "drivers: KernelSU"
KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
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

echo -e " \nincludes ReSukiSU, ver ${KSU_ver}" >> banner_append
echo -e " \nincludes NoMount v2.0.0" >> banner_append
