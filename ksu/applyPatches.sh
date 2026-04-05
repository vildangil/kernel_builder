#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Полная очистка перед патчингом
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra (KernelSU + SusFS) ---"
# Автоматический скрипт установки SukiSU
if ! curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2; then
    echo "Ошибка: setup.sh не смог примениться"
    exit 1
fi

# Проверка Makefile на наличие KernelSU
if ! grep -q "kernelsu" drivers/Makefile; then
    echo "obj-y += kernelsu/" >> drivers/Makefile
fi

# Настройка дефконфига
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Настройка конфига: $TARGET_CONFIG ---"
    # Очистка старых параметров
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    
    # Добавление флагов SukiSU
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
EOF
    # Установка твоего названия ядра
    sed -i "s/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-BlacksideKernel_blossom\"/g" "$TARGET_CONFIG"
else
    echo "Ошибка: Файл конфигурации не найден по пути $TARGET_CONFIG"
    exit 1
fi

git add .
git commit -m "Integrated SukiSU Ultra and set kernel name"
