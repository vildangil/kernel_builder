#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс правок
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra ---"
# Скачиваем саму папку с кодом KSU
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -

# --- ВЗЛОМ KCONFIG (КРИТИЧНО) ---
# Убираем все "depends on", которые мешают сборке KSU на старых ядрах
if [ -f "drivers/kernelsu/Kconfig" ]; then
    echo "--- Взлом Kconfig для принудительной сборки ---"
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
    sed -i 's/bool "KernelSU support"/bool "KernelSU support"\n    default y/g' drivers/kernelsu/Kconfig
fi

# Прописываем папку в Makefile
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# --- ПРИМЕНЕНИЕ ПАТЧЕЙ ДЛЯ SUSFS ---
# Убедись, что папки patches и sus_patches существуют в твоем репо
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

if [ -d "$patchesdir" ]; then
    git am "$patchesdir"/*.patch || echo "Ошибка патчей KSU - пропускаем"
fi
if [ -d "$suspatchesdir" ]; then
    git am "$suspatchesdir"/*.patch || echo "Ошибка патчей SusFS - пропускаем"
fi

# --- НАСТРОЙКА DEFCONFIG ---
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Принудительная вставка конфигов ---"
    # Удаляем старое
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_OVERLAY_FS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_LOCALVERSION/d' "$TARGET_CONFIG"
    
    # Добавляем жестко в конец
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_LOCALVERSION="-BlacksideKernel_blossom"
EOF
fi

git add .
git commit -m "Force integrate SukiSU Ultra"
