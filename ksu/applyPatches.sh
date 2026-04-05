#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git (нужно для патчей)
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Очистка перед работой
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra ---"
# Скачиваем код SukiSU
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2

# --- ХАК: Принудительная сборка ---
# На 4.19 KSU часто не видит KPROBES. Уберем зависимость в Kconfig.
if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
    echo "--- Зависимости Kconfig удалены ---"
fi

# Гарантируем, что папка прописана в Makefile
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# --- ПРИМЕНЕНИЕ ПАТЧЕЙ ---
# Проверяем наличие папок с патчами (путь зависит от структуры твоего репозитория)
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

if [ -d "$patchesdir" ]; then
    echo "--- Применяем патчи KSU ---"
    git am "$patchesdir"/*.patch || echo "Патчи KSU не наложены (возможно, уже есть в коде)"
fi

if [ -d "$suspatchesdir" ]; then
    echo "--- Применяем патчи SusFS ---"
    git am "$suspatchesdir"/*.patch || echo "Патчи SusFS не наложены"
fi

# --- ЖЕСТКАЯ ПРАВКА КОНФИГА ---
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Инъекция параметров в $TARGET_CONFIG ---"
    # Удаляем старые упоминания, чтобы избежать конфликтов
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_OVERLAY_FS/d' "$TARGET_CONFIG"
    
    # Включаем всё необходимое принудительно
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_HAVE_KPROBES=y
CONFIG_OVERLAY_FS=y
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_LOCALVERSION="-BlacksideKernel_blossom"
EOF
fi

git add .
git commit -m "Force KSU and SusFS integration"
