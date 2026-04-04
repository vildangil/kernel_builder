#!/bin/bash
# asus.sh — Исправленная версия для blossom 4.19

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git (обязательно для коммитов в CI)
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс зависших патчей, если они были
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Скачиваем SukiSU Ultra ---"
# Используем флаг -s для выбора версии (main или конкретная)
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2

# ПРОВЕРКА MAKEFILE: Если setup.sh не прописал папку, пропишем сами
if ! grep -q "kernelsu" drivers/Makefile; then
    echo "obj-y += kernelsu/" >> drivers/Makefile
    echo "--- Добавлена папка kernelsu в Makefile вручную ---"
fi

git add . && git commit -am "drivers: SukiSU Ultra integration"

# Пути к патчам
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

# Настройка дефконфига
TARGET_CONFIG="${defconfig_file}"
echo "--- Тюнинг конфига: $TARGET_CONFIG ---"

# Включаем всё необходимое
cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_HAVE_KPROBES=y
CONFIG_OVERLAY_FS=y
EOF

# Переименование
sed -i 's/CONFIG_LOCALVERSION="-TsukiNoHikari"/CONFIG_LOCALVERSION="-SukaKernel"/g' "$TARGET_CONFIG"

echo "--- Настройка завершена! ---"
