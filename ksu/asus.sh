#!/bin/bash
# Установка SukiSU Ultra и SUSFS с коротким названием SukiSUS

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Установка SukiSU Ultra по правильной ссылке
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-main
git add . && git commit -am "drivers: SukiSU Ultra"

KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 10000 + 200))

# Определение путей к патчам
patchesdir="$outside/ksu/patches/$(echo $kernel_ver | cut -d. -f1,2)"
suspatchesdir="$outside/ksu/sus_patches/$(echo $kernel_ver | cut -d. -f1,2)"

# Применение бэкпортов SukiSU
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
  if ls "$suspatchesdir"/*.patch 1> /dev/null 2>&1; then
    for patch_file in "$suspatchesdir"/*.patch ; do
      git am "$patch_file"
    done
  else
    echo "patching ksu susfs failed: no .patch files inside $suspatchesdir"
    exit 1
  fi
else
  echo "patching ksu susfs failed: directory $suspatchesdir not found"
  exit 1
fi

# Включаем SukiSU и SUSFS в конфигурации ядра
echo "CONFIG_KSU=y" >> "${defconfig_file}"
echo "CONFIG_KSU_SUSFS=y" >> "${defconfig_file}"

# Обновление имени ядра на SukiSUS
sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-SukiSUS\"/" "${defconfig_file}"

echo "Config updated: $(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"
