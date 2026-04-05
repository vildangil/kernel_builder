#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git для работы с патчами
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Очистка перед началом
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra (Pure) ---"
# Удаляем старую папку и скачиваем SukiSU Ultra
rm -rf drivers/kernelsu
git clone https://github.com/sukisu-ultra/sukisu-ultra drivers/kernelsu

# --- ГАРАНТИЯ СБОРКИ (КРИТИЧНО) ---
# 1. Прописываем в Makefile
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# 2. Убираем все зависимости в Kconfig, чтобы модуль не отключился
if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
fi

# --- НАСТРОЙКА DEFCONFIG ---
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Настройка $TARGET_CONFIG ---"
    # Удаляем старые записи KSU и SusFS
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_OVERLAY_FS/d' "$TARGET_CONFIG"
    
    # Добавляем только нужные флаги
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
CONFIG_KSU=y
CONFIG_LOCALVERSION="-Blackside_SukiSU"
EOF
fi

# Сохраняем изменения, чтобы GitHub Actions их увидел
git add .
git commit -m "Integrate SukiSU Ultra (No SusFS)"
