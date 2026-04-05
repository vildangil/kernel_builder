#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Очистка перед началом
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra (KSU + SusFS) ---"
# Используем официальный установщик SukiSU
if ! curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2; then
    echo "Ошибка: setup.sh не смог примениться"
    exit 1
fi

# Проверка Makefile
if ! grep -q "kernelsu" drivers/Makefile; then
    echo "obj-y += kernelsu/" >> drivers/Makefile
fi

# Настройка дефконфига
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Настройка конфига: $TARGET_CONFIG ---"
    # Удаляем старые параметры, чтобы не было дублей
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    
    # Добавляем нужные флаги
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
EOF
    # Ставим твое название ядра
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-SukaKernel-SukiSU"/g' "$TARGET_CONFIG"
fi

git add .
git commit -m "Integrated SukiSU Ultra"
