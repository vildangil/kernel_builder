#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс текущих правок, чтобы избежать конфликтов
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra (Без SusFS) ---"
# Удаляем старую папку и качаем именно SukiSU Ultra
rm -rf drivers/kernelsu
git clone https://github.com/sukisu-ultra/sukisu-ultra drivers/kernelsu

# --- ГАРАНТИЯ ВКЛЮЧЕНИЯ В СБОРКУ ---
# Прописываем папку в главный Makefile драйверов
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# Взлом Kconfig: убираем зависимости (depends on), чтобы KSU не выключился сам
if [ -f "drivers/kernelsu/Kconfig" ]; then
    echo "--- Взлом Kconfig для принудительной активации ---"
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
fi

# --- НАСТРОЙКА DEFCONFIG ---
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Настройка параметров в $TARGET_CONFIG ---"
    # Вырезаем всё старое (KSU и SusFS), чтобы записать начисто
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_OVERLAY_FS/d' "$TARGET_CONFIG"
    
    # Добавляем только SukiSU и необходимые системные компоненты
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
CONFIG_KSU=y
CONFIG_LOCALVERSION="-Blackside_SukiSU"
EOF
fi

# Сохраняем изменения в коммит, чтобы компилятор их увидел
git add .
git commit -m "Integrate SukiSU Ultra"
