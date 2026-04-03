#!/bin/bash
# asus.sh — SukiSU Ultra + SUSFS + SukiSUS name

export maindir="$(pwd)"
# Так как ядро в папке /kernel, выходим на уровень выше к сборщику
export outside="${maindir}/.."
source "${outside}/$1env"

# 1. Установка именно SukiSU Ultra
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-main
git add . && git commit -am "drivers: SukiSU Ultra"

# 2. Пути к патчам (ищем их в папке ksu сборщика)
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

# 3. Накладываем патчи
if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file" || git am --abort
  done
fi

if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file" || git am --abort
  done
fi

# 4. ВКЛЮЧАЕМ РУТ В КОНФИГЕ (Без этого не будет работать!)
# Путь: arch/arm64/configs/blossom_defconfig
echo "CONFIG_KSU=y" >> "arch/arm64/configs/${defconfig_file}"
echo "CONFIG_KSU_SUSFS=y" >> "arch/arm64/configs/${defconfig_file}"

# 5. Меняем название на SukiSUS
sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-SukiSUS\"/" "arch/arm64/configs/${defconfig_file}"

echo "Done! Localversion: $(grep 'CONFIG_LOCALVERSION' arch/arm64/configs/${defconfig_file})"
