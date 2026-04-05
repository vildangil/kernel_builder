#!/bin/bash
#
# SukiSU Ultra + SusFS v2.1.0 (Optimized for Kernel 4.19)

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$1env"

# Настройка Git
git config --global user.email "bot@example.com"
git config --global user.name "Kernel Bot"

# Сброс текущего состояния Git
git am --abort >/dev/null 2>&1
git reset --hard HEAD

echo "--- Установка SukiSU Ultra + SusFS v2.1.0 Backport ---"
# Скачивание SukiSU Ultra с флагом бэкпорта SusFS
curl -LSs "https://raw.githubusercontent.com/sukisu-ultra/sukisu-ultra/main/kernel/setup.sh" | bash -s susfs-v2.1.0
git add . && git commit -am "drivers: SukiSU Ultra + SusFS source"

# --- ИСПРАВЛЕНИЕ ОШИБОК КОМПИЛЯЦИИ (init.c и ksu.c) ---
echo "--- Применение фиксов исходного кода для ядра 4.19 ---"

# 1. Создаем вспомогательный заголовочный файл, чтобы функции были видны во всех файлах KSU
cat <<EOF > drivers/kernelsu/ksu_fix.h
#ifndef KSU_FIX_H
#define KSU_FIX_H
#include <linux/fs.h>
struct file;
int ksu_handle_fops(struct file *file);
void ksu_dentry_init(void);
#endif
EOF

# 2. Принудительно подключаем фикс-хедер и недостающие системные библиотеки в проблемные файлы
# Это исправляет ошибки "implicit declaration of function"
sed -i '1i #include "ksu_fix.h"' drivers/kernelsu/ksu.c
sed -i '1i #include "ksu_fix.h"' drivers/kernelsu/init.c

# Добавляем планировщик и работу с файлами в init.c (критично для 4.19)
sed -i '1i #include <linux/sched.h>\n#include <linux/file.h>\n#include <linux/version.h>' drivers/kernelsu/init.c

# 3. Делаем функции глобальными (убираем static), чтобы линковщик их нашел
sed -i 's/static int ksu_handle_fops/int ksu_handle_fops/g' drivers/kernelsu/ksu.c 2>/dev/null
sed -i 's/static void ksu_dentry_init/void ksu_dentry_init/g' drivers/kernelsu/init.c 2>/dev/null

git add . && git commit -m "drivers: fix SukiSU compilation errors for 4.19"

# --- ПРИМЕНЕНИЕ ЛОКАЛЬНЫХ ПАТЧЕЙ ---
patchesdir="$outside/ksu/patches/"
suspatchesdir="$outside/ksu/sus_patches/"

# Патчи KSU
if [[ -d "$patchesdir" ]]; then
  echo "--- Применение патчей KSU ---"
  for patch_file in "$patchesdir"/*.patch ; do
    git am "$patch_file" || echo "Ошибка: патч KSU $patch_file не применился"
  done
fi

# Патчи SusFS
if [[ -d "$suspatchesdir" ]]; then
  echo "--- Применение патчей SusFS ---"
  for patch_file in "$suspatchesdir"/*.patch ; do
    git am "$patch_file" || echo "Ошибка: патч SusFS $patch_file не применился"
  done
fi

# --- НАСТРОЙКА СБОРКИ ---
# Гарантируем, что папка kernelsu прописана в Makefile
sed -i '/kernelsu/d' drivers/Makefile
echo "obj-y += kernelsu/" >> drivers/Makefile

# Убираем зависимости в Kconfig, чтобы KSU не отключился
if [ -f "drivers/kernelsu/Kconfig" ]; then
    sed -i 's/depends on .*//g' drivers/kernelsu/Kconfig
fi

# --- ОБНОВЛЕНИЕ DEFCONFIG (БЕЗ ИЗМЕНЕНИЯ НАЗВАНИЯ ЯДРА) ---
echo "--- Включение флагов в defconfig ---"
{
  echo 'CONFIG_KPROBES=y'
  echo 'CONFIG_KPROBE_EVENTS=y'
  echo 'CONFIG_OVERLAY_FS=y'
  echo 'CONFIG_KSU=y'
  echo 'CONFIG_KSU_SUSFS=y'
  echo 'CONFIG_SUSFS=y'
  echo 'CONFIG_SUSFS_VERSION="v2.1.0"'
} >> "${defconfig_file}"

git add .
git commit -m "Integrate SukiSU Ultra + SusFS v2.1.0 with source fixes"

echo -e " \nincludes SukiSU Ultra with SusFS v2.1.0" >> banner_append
