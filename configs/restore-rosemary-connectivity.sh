#!/usr/bin/env bash
# Restore MediaTek MT6785 connectivity drivers absent from evolution/shadow.
# Run from the kernel source root before defconfig and compilation.
set -euo pipefail

[[ -f Makefile && -f drivers/misc/mediatek/connectivity/Makefile ]] || {
  echo "Run from the kernel source root" >&2; exit 2;
}
target="drivers/misc/mediatek/connectivity"
if ! grep -q 'Do Nothing, move to standalone repo' "$target/Makefile"; then
  echo "Connectivity tree is not the known shadow stub; refusing to overwrite it" >&2
  exit 1
fi

repo="${CONNECTIVITY_REPO:-https://github.com/vildangil/android_kernel_xiaomi_rosemary-s.git}"
ref="${CONNECTIVITY_BRANCH:-rosemary-13}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A partial checkout avoids cloning the entire multi-gigabyte kernel tree.
git clone --quiet --depth=1 --single-branch --branch "$ref" \
  --filter=blob:none --sparse "$repo" "$tmp/source"
git -C "$tmp/source" sparse-checkout set "$target"
source_dir="$tmp/source/$target"

[[ -f "$source_dir/common/common_detect/wmt_detect.c" ]] || {
  echo "Missing WMT device driver in the donor tree" >&2; exit 1;
}
[[ -f "$source_dir/wlan/core/gen4m/Makefile" ]] || {
  echo "Missing MT6785 WLAN driver in the donor tree" >&2; exit 1;
}
[[ -f "$source_dir/bt/mt66xx/stp_chrdev_bt.c" ]] || {
  echo "Missing /dev/stpbt Bluetooth driver in the donor tree" >&2; exit 1;
}
grep -Fq 'obj-$(CONFIG_MTK_COMBO_BT) += bt/mt66xx/' "$source_dir/Makefile" || {
  echo "Donor Makefile does not build the Bluetooth driver" >&2; exit 1;
}
[[ -f "$source_dir/Makefile" ]] || exit 1

rm -rf "$target"
cp -a "$source_dir" "$target"

# The evolution/shadow defconfig enables WMT and Wi-Fi but omits the MTK
# /dev/stpbt character driver. Re-enable the exact built-in driver shipped
# with the rosemary-s connectivity tree; do not alter unrelated configs.
defconfig=arch/arm64/configs/rosemary_defconfig
if ! grep -qx 'CONFIG_MTK_COMBO_BT=y' "$defconfig"; then
  sed -i '/^CONFIG_MTK_COMBO_BT=/d; /^# CONFIG_MTK_COMBO_BT is not set$/d' "$defconfig"
  printf '\nCONFIG_MTK_COMBO_BT=y\n' >> "$defconfig"
  echo "Enabled CONFIG_MTK_COMBO_BT=y for /dev/stpbt"
fi

for symbol in MTK_COMBO MTK_COMBO_CHIP_CONSYS_6785 MTK_COMBO_WIFI MTK_COMBO_BT; do
  if ! grep -qx "CONFIG_${symbol}=y" arch/arm64/configs/rosemary_defconfig; then
    echo "Required ${symbol}=y missing in rosemary_defconfig" >&2
    exit 1
  fi
done

printf 'Restored MT6785 built-in WMT/WLAN/BT drivers from %s (%s)\n' \
  "$repo" "$(git -C "$tmp/source" rev-parse --short HEAD)"
