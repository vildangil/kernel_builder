#!/bin/bash
# asus.sh — Исправленная интеграция SukiSU Ultra + SUSFS

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git (без этого commit упадет и SukiSU не встроится)
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

echo "--- Начинаем установку SukiSU Ultra ---"

# 1. Установка SukiSU Ultra
# Используем -s main или конкретную версию. Добавляем проверку на успех.
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v1.5.2 || exit 1
git add . && git commit -am "drivers: SukiSU Ultra integration"

# 2. Определение путей к патчам
patchesdir="$outside/ksu/patches/4.19"
suspatchesdir="$outside/ksu/sus_patches/4.19"

# 3. Накладываем патчи (убрали --abort, чтобы видеть ошибки в логах)
echo "--- Накладываем VFS патчи ---"
if [[ -d "$patchesdir" ]]; then
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file" || { echo "Ошибка в патче $patch_file"; git am --skip; }
  done
fi

echo "--- Накладываем SUSFS патчи ---"
if [[ -d "$suspatchesdir" ]]; then
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file" || { echo "Ошибка в патче $patch_file"; git am --skip; }
  done
fi

# 4. ПРАВИЛЬНОЕ ВКЛЮЧЕНИЕ В КОНФИГЕ
# Твоя переменная defconfig_file уже содержит путь, не добавляем arch/arm64/...
TARGET_CONFIG="${defconfig_file}"

echo "--- Настройка дефконфига: $TARGET_CONFIG ---"

# Удаляем старые упоминания, если они были
sed -i '/CONFIG_KSU/d' "$TARGET_CONFIG"
sed -i '/CONFIG_KPROBES/d' "$TARGET_CONFIG"
sed -i '/CONFIG_OVERLAY_FS/d' "$TARGET_CONFIG"

# Добавляем необходимые параметры
cat <<EOF >> "$TARGET_CONFIG"
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_SUSFS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_HAVE_KPROBES=y
CONFIG_OVERLAY_FS=y
EOF

# Переименование ядра (исправленный путь)
sed -i 's/CONFIG_LOCALVERSION="-TsukiNoHikari"/CONFIG_LOCALVERSION="-SukaKernel"/g' "$TARGET_CONFIG"

echo "--- Готово! ---"
