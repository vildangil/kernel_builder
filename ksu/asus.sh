#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка гита
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс только ДО начала всех работ
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU (KSU + SusFS) ---"
# setup.sh от SukiSU сам скачивает KSU и патчит файлы
if ! curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2; then
    echo "ОШИБКА: setup.sh не отработал"
    exit 1
fi

# Проверяем Makefile (только одна запись!)
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# Включаем опции в конфиге ПРАВИЛЬНО
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig" # Укажи точный путь если переменная не подхватилась
if [ -f "$TARGET_CONFIG" ]; then
    echo "--- Настройка дефконфига ---"
    # Удаляем старые упоминания, если они были
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    
    cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_OVERLAY_FS=y
EOF
    # Исправляем название ядра
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-SukaKernel"/g' "$TARGET_CONFIG"
fi

git add .
git commit -m "Integrated SukiSU and updated config"
echo "--- Все готово для сборки ---"
