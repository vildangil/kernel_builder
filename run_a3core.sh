#!/bin/bash
# Local A03 Core builder entrypoint.
# Usage: cp priv_env.dist priv_env && edit priv_env && ./run_a3core.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

if [ ! -f priv_env ]; then
  echo "priv_env not found. Copy priv_env.dist to priv_env and edit it." >&2
  exit 2
fi

# shellcheck disable=SC1091
source ./priv_env

: "${KDIR:=kernel}"
: "${kernel_repo:=https://github.com/vildangil/android_kernel_m168}"
: "${kernel_branch:=4.14.199-erofs}"
: "${DEFCONFIG:=a3core_eur_open_defconfig}"
: "${COMPILERS:=A03-Clang}"
: "${BUILD_FILESYSTEM:=EROFS}"
: "${ROOT_SOLUTION:=ReSukiSU}"
: "${CM4_WATCHDOG_OFF:=true}"
: "${PERMISSIVE:=false}"

export DEFCONFIG COMPILERS BUILD_FILESYSTEM ROOT_SOLUTION CM4_WATCHDOG_OFF PERMISSIVE
export zipper_repo zipper_branch SUFFIX NOTE BOT_TOKEN CHAT_ID

telegram() {
  if [ -n "${BOT_TOKEN:-}" ] && [ -n "${CHAT_ID:-}" ]; then
    bash "$ROOT_DIR/tg_utils.sh" msg "$1" || true
  fi
}

upload() {
  if [ -n "${BOT_TOKEN:-}" ] && [ -n "${CHAT_ID:-}" ] && [ -f "$1" ]; then
    bash "$ROOT_DIR/tg_utils.sh" up "$1" "$2" || true
  fi
}

START="$(date +%s)"
telegram "local A03 Core build started%nlbranch: ${kernel_branch}%nlfs: ${BUILD_FILESYSTEM}%nlroot: ${ROOT_SOLUTION}%nlcm4 watchdog off: ${CM4_WATCHDOG_OFF}%nlcompiler: ${COMPILERS}"

if [ -d "$KDIR/.git" ]; then
  git -C "$KDIR" fetch origin "$kernel_branch" --depth=1
  git -C "$KDIR" checkout -B "$kernel_branch" FETCH_HEAD
  git -C "$KDIR" reset --hard FETCH_HEAD
  git -C "$KDIR" clean -fdx
else
  rm -rf "$KDIR"
  git clone --depth=1 --single-branch -b "$kernel_branch" "$kernel_repo" "$KDIR"
fi

cd "$KDIR"
telegram "local build: preparing source"
bash "$ROOT_DIR/prepare_a3core.sh"

set +e
bash "$ROOT_DIR/build.sh" "$COMPILERS"
RET=$?
set -e

END="$(date +%s)"
DIFF=$((END - START))

if [ "$RET" -ne 0 ]; then
  telegram "local A03 Core build failed%nlafter: $((DIFF / 60))m $((DIFF % 60))s"
  shopt -s nullglob
  for file in *.log; do
    upload "$PWD/$file" "A03 Core failed compiler log"
  done
  exit "$RET"
fi

shopt -s nullglob
for file in *.zip; do
  caption="A03 Core ${BUILD_FILESYSTEM} ${ROOT_SOLUTION}"
  [ -f "${file}.info" ] && caption="$(cat "${file}.info")"
  upload "$PWD/$file" "$caption"
done
for file in *.log; do
  caption="A03 Core compiler log"
  [ -f "${file}.info" ] && caption="$(cat "${file}.info")"
  upload "$PWD/$file" "$caption"
done

if [ -s out/arch/arm64/boot/Image ]; then
  upload "$PWD/out/arch/arm64/boot/Image" "A03 Core raw Image | ${BUILD_FILESYSTEM} | ${ROOT_SOLUTION}"
fi
if [ -f out/.config ]; then
  cp out/.config "A03-Core-${BUILD_FILESYSTEM}-${ROOT_SOLUTION}.config"
  upload "$PWD/A03-Core-${BUILD_FILESYSTEM}-${ROOT_SOLUTION}.config" "A03 Core kernel config"
fi

telegram "local A03 Core build finished%ntime: $((DIFF / 60))m $((DIFF % 60))s%nlfs: ${BUILD_FILESYSTEM}%nlroot: ${ROOT_SOLUTION}"
