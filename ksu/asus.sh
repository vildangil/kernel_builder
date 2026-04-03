#!/bin/bash
# SukiSU Ultra & SUSFS для раздельных репозиториев

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# 1. Установка SukiSU Ultra
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-main
git add . && git commit -am "drivers: SukiSU Ultra"

KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 10000 + 200))

# 2. Умный поиск папок с патчами
# Проверяем сначала снаружи (как было), потом внутри (если скачали в корень ядра)
if [[ -d "$outside/ksu" ]]; then
    KSU_ROOT="$outside/ksu"
elif [[ -d "$maindir/ksu" ]]; then
    KSU_ROOT="$maindir/ksu"
else
    echo "WARNING: ksu folder not found anywhere! Root will be built without patches."
fi

# 3. Применение патчей SukiSU
if [[ -n "$KSU_ROOT" && -d "$KSU_ROOT/patches/4.19" ]]; then
  echo "Applying patches from $KSU_ROOT/patches/4.19"
  for patch_file in "$KSU_ROOT/patches/4.19"/*.patch ; do
    git am "$patch_file" || echo "Failed to apply $patch_file"
  done
fi

# 4. Применение патчей SUSFS
if [[ -n "$KSU_ROOT" && -d "$KSU_ROOT/sus_patches/4.19" ]]; then
  echo "Applying SUSFS patches from $KSU_ROOT/sus_patches/4.19"
  for patch_file in "$KSU_ROOT/sus_patches/4.19"/*.patch ; do
    git am "$patch_file" || echo "Failed to apply $patch_file"
  done
fi

# 5. Включение конфигов (ОБЯЗАТЕЛЬНО)
echo "CONFIG_KSU=y" >> "${defconfig_file}"
echo "CONFIG_KSU_SUSFS=y" >> "${defconfig_file}"

# 6. Название SukiSUS
sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-SukiSUS\"/" "${defconfig_file}"

echo "Final check: $(grep 'CONFIG_KSU' ${defconfig_file})"
