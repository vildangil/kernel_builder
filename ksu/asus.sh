#!/bin/bash
#
# hdjsjfjjwufbeizihfjejzf

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Скачиваем SukiSU Ultra вместо обычного KernelSU
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-main
git add . && git commit -am "drivers: SukiSU Ultra"

# setup.sh форков обычно оставляет название папки KernelSU для обратной совместимости
KSU_git_ver=$(cd KernelSU && git rev-list --count HEAD)
KSU_ver=$(($KSU_git_ver + 10000 + 200))

# Скрипт ищет патчи на один уровень выше текущей папки (в outside)
patchesdir="$outside/ksu/patches/$(echo $kernel_ver | cut -d. -f1,2)"
suspatchesdir="$outside/ksu/sus_patches/$(echo $kernel_ver | cut -d. -f1,2)"

if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching SukiSU failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file"
  done
else
  echo "patching susfs failed, the kernel version you want to patch doesnt have patches here yet"
  exit 1
fi

# Прописываем версию в defconfig (оставил логику почти нетронутой, чтобы переменная ${kernel_name} корректно подхватила название твоего проекта, будь то SukaKernel или что-то другое)
sed -i "s/\(CONFIG_LOCALVERSION=\)\(.*\)/\1\"-${kernel_name}-SukiUltra-ks${KSU_ver}sus\"/" "${defconfig_file}"

echo "$(grep 'CONFIG_LOCALVERSION=' ${defconfig_file})"

echo -e " \nincludes SukiSU Ultra fork, ver ${KSU_ver}" >> banner_append
echo -e " \nincludes SuSFS v2.0.0 (Latest)" >> banner_append
