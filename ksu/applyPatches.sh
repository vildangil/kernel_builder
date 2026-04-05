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

echo "--- Установка KernelSU ---"
# Скачиваем KernelSU напрямую (не через setup.sh, если он подводит)
rm -rf drivers/kernelsu
git clone https://github.com/tiann/KernelSU drivers/kernelsu

# --- ВЗЛОМ MAKEFILE (ПРИНУДИТЕЛЬНО) ---
# Удаляем старые записи и добавляем KSU в самый верх списка сборки драйверов
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# --- ВЗЛОМ KCONFIG ---
# На 4.19 KSU часто не включается из-за зависимостей. Убираем их.
if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
fi

# --- ПРИМЕНЕНИЕ ПАТЧЕЙ SUSFS ---
# Убедись, что пути к патчам верны
patchesdir="$outside/ksu/patches/4.19"
if [ -d "$patchesdir" ]; then
    git am "$patchesdir"/*.patch || echo "Ошибка патчей — пропускаем"
fi

# --- НАСТРОЙКА DEFCONFIG ---
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Принудительная вставка конфигов в $TARGET_CONFIG ---"
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
CONFIG_KSU=y
CONFIG_SUSFS=y
CONFIG_KSU_SUSFS=y
EOF
fi

# ВАЖНО: Добавляем ВСЕ новые файлы (включая папку drivers/kernelsu) в коммит
git add .
git commit -m "Integrate KernelSU and SusFS - Full Source"
