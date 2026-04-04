#!/bin/bash
# asus.sh — Исправленная версия для blossom 4.19

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git (нужна для git am)
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Чистим следы перед началом
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra ---"
# Выполняем базовую установку
if ! curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2; then
    echo "ОШИБКА: Не удалось выполнить setup.sh"
    exit 1
fi

# Пути к патчам
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

# Применяем дополнительные патчи, если папки существуют
if [ -d "$patchesdir" ]; then
    echo "--- Применяем патчи KernelSU ---"
    git am "$patchesdir"/*.patch || echo "Внимание: некоторые патчи KSU не применились"
fi

if [ -d "$suspatchesdir" ]; then
    echo "--- Применяем патчи SusFS ---"
    git am "$suspatchesdir"/*.patch || echo "Внимание: некоторые патчи SusFS не применились"
fi

# Проверка Makefile
if ! grep -q "kernelsu" drivers/Makefile; then
    echo "obj-y += kernelsu/" >> drivers/Makefile
fi

git add . && git commit -m "drivers: SukiSU Ultra integration and patches"

# Настройка дефконфига
TARGET_CONFIG="${defconfig_file}"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Тюнинг конфига: $TARGET_CONFIG ---"
    # Удаляем старые параметры, чтобы не дублировать
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_HAVE_KPROBES=y
CONFIG_OVERLAY_FS=y
EOF
    # Меняем LOCALVERSION более универсально
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-Blackside_Kernel_Blossom"/g' "$TARGET_CONFIG"
else
    echo "ОШИБКА: Файл конфига $TARGET_CONFIG не найден!"
    exit 1
fi

echo "--- Настройка завершена успешно! ---"
