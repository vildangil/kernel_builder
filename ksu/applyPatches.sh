#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git (без этого патчи не применятся)
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс перед началом
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra ---"
# Скачиваем ядро KSU/SukiSU
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -

# ---------------------------------------------------------
# ХАК: Принудительно заставляем KSU собираться
# Удаляем зависимости, из-за которых сборщик "выплевывает" KSU
if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i '/depends on/d' drivers/kernelsu/Kconfig
    sed -i 's/default n/default y/g' drivers/kernelsu/Kconfig
fi

sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile
# ---------------------------------------------------------

# ВОЗВРАЩАЕМ ПРИМЕНЕНИЕ ПАТЧЕЙ (для SusFS и KSU)
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

if [ -d "$patchesdir" ]; then
    echo "--- Применяем патчи KernelSU ---"
    git am "$patchesdir"/*.patch || echo "Внимание: ошибка наложения патчей KSU"
fi

if [ -d "$suspatchesdir" ]; then
    echo "--- Применяем патчи SusFS ---"
    git am "$suspatchesdir"/*.patch || echo "Внимание: ошибка наложения патчей SusFS"
fi

# Настраиваем конфиг
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Тюнинг конфига ---"
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_LOCALVERSION/d' "$TARGET_CONFIG"
    
    # Врубаем модули и пробы принудительно
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_MODULES=y
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
git commit -m "Integrated SukiSU, SusFS patches, and forced Kconfig"
