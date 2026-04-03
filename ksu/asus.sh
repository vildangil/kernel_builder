#!/bin/bash
# Чистая установка SukiSU Ultra и SUSFS

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Установка SukiSU Ultra
curl -LSs "https://raw.githubusercontent.com/502648092/SukiSU/main/kernel/setup.sh" | bash -s susfs-main
git add . && git commit -am "drivers: SukiSU Ultra"

KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 10000 + 200))

# Определение путей к патчам на основе версии ядра (4.19)
patchesdir="$outside/ksu/patches/$(echo $kernel_ver | cut -d. -f1,2)"
suspatchesdir="$outside/ksu/sus_patches/$(echo $kernel_ver | cut -d. -f1,2)"

# Применение бэкпортов и патчей SukiSU
if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu failed: directory $patchesdir not found"
  exit 1
fi

# Применение патчей SUSFS
if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching ksu susfs failed: directory $suspatchesdir not found"
  exit 1
fi

# Обновление версии только в конфигурации ядра
sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-SukiUltra-ks${KSU_ver}sus\"/" "${defconfig_file}"

echo "Config updated: $(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"
