#!/bin/bash
export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git (критично для SukiSU)
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс, чтобы не было конфликтов
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra ---"
# Авто-установщик SukiSU
if ! curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2; then
    echo "Ошибка: SukiSU не установился!"
    exit 1
fi

# Прописываем название ядра и включаем конфиги
TARGET_CONFIG="arch/arm64/configs/blossom_defconfig"
if [ -f "$TARGET_CONFIG" ]; then
    # Удаляем старые упоминания KSU/SUSFS
    sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_SUSFS/d' "$TARGET_CONFIG"
    sed -i '/CONFIG_LOCALVERSION/d' "$TARGET_CONFIG"
    
    # Добавляем всё заново в конец
    echo 'CONFIG_KSU=y' >> "$TARGET_CONFIG"
    echo 'CONFIG_KSU_SUSFS=y' >> "$TARGET_CONFIG"
    echo 'CONFIG_SUSFS=y' >> "$TARGET_CONFIG"
    echo 'CONFIG_KPROBES=y' >> "$TARGET_CONFIG"
    echo 'CONFIG_KPROBE_EVENTS=y' >> "$TARGET_CONFIG"
    echo "CONFIG_LOCALVERSION=\"-BlacksideKernel_blossom\"" >> "$TARGET_CONFIG"
fi

git add . && git commit -m "Integrated SukiSU Ultra"
