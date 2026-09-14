#!/usr/bin/env bash
# Local A03 Core wrapper with the same Telegram lifecycle as GitHub Actions.
# Usage:
#   ./wrapper.sh [env-prefix] [clean]
# Examples:
#   ./wrapper.sh
#   ./wrapper.sh test clean   # sources testpriv_env + testenv

set -o pipefail

sln=$(readlink -f "$0")
spath=$(dirname "$sln")
export OLDDIR=$(pwd)
cd "$spath" || exit 1

PREFIX="${1:-}"
PRIV_ENV="./${PREFIX}priv_env"
PUBLIC_ENV="./${PREFIX}env"

source "$PRIV_ENV" || {
  echo "incorrect envset: $PRIV_ENV does not exist"
  exit 127
}

RUN_ID=$(shuf -ern4 {0..9} | sha1sum - | head -c 8)
RUN_START=$(date +"%s")
RES=0

finish() {
  local rc=$?
  local run_end diff status
  run_end=$(date +"%s")
  diff=$((run_end - RUN_START))
  if [ "$rc" -eq 0 ] && [ "$RES" = "1" ]; then
    status="ended successfully"
  else
    status="failed"
  fi
  bash tg_utils.sh msg "$RUN_ID: A03 Core run $status in $((diff / 60))m, $((diff % 60))s%nlfs: ${BUILD_FILESYSTEM:-?}%nlroot: ${ROOT_SOLUTION:-?}%nlcm4 watchdog off: ${CM4_WATCHDOG_OFF:-?}" || true
  cd "$OLDDIR" || true
}
trap finish EXIT

bash tg_utils.sh msg "$RUN_ID: A03 Core run started" || true
bash tg_utils.sh msg "$RUN_ID: using envset '${PREFIX:-default}'" || true

[ -z "$KDIR" ] && {
  echo "$RUN_ID: KDIR was not set"
  exit 127
}

: "${kernel_repo:=https://github.com/vildangil/android_kernel_m168}"
: "${kernel_branch:=4.14.199-erofs}"
: "${COMPILERS:=A03-Clang}"
: "${BUILD_FILESYSTEM:=EROFS}"
: "${ROOT_SOLUTION:=ReSukiSU}"
: "${CM4_WATCHDOG_OFF:=true}"
: "${PERMISSIVE:=false}"
: "${DEFCONFIG:=a3core_eur_open_defconfig}"

export kernel_repo kernel_branch COMPILERS BUILD_FILESYSTEM ROOT_SOLUTION
export CM4_WATCHDOG_OFF PERMISSIVE DEFCONFIG

bash tg_utils.sh msg "$RUN_ID: kernel dir: $KDIR%nlrepo: $kernel_repo%nlbranch: $kernel_branch" || true
bash tg_utils.sh msg "$RUN_ID: fs=$BUILD_FILESYSTEM root=$ROOT_SOLUTION cm4_off=$CM4_WATCHDOG_OFF permissive=$PERMISSIVE compiler=$COMPILERS" || true

if [ -n "$NOTE" ]; then
  bash tg_utils.sh msg "$RUN_ID: $NOTE" || true
fi

if [ -n "$VERBOSE" ]; then
  bash tg_utils.sh msg "$RUN_ID: host: $(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2)%nlfree disk: $(df --sync -BM --output=avail / | tail -n 1 | xargs)" || true
fi

if [ ! -d "$KDIR/.git" ]; then
  rm -rf "$KDIR"
  git clone --depth=1 --single-branch "$kernel_repo" -b "$kernel_branch" "$KDIR" || exit 1
else
  cd "$KDIR" || exit 1
  git reset --hard
  git fetch origin "$kernel_branch"
  git checkout "$kernel_branch"
  git reset --hard "origin/$kernel_branch"
  git submodule update --init --recursive
  cd "$spath" || exit 1
fi

if [ "${2:-}" = "clean" ]; then
  rm -rf "$KDIR/out" "$spath/zipper-a3core" "$spath/a03-clang-r383902b" "$spath/a03-gcc-14.3"
fi

cd "$KDIR" || exit 1
source "../${PREFIX}env" || {
  bash ../tg_utils.sh msg "$RUN_ID: public env '${PREFIX}env' missing" || true
  exit 127
}

bash ../tg_utils.sh msg "$RUN_ID: kernel: ${kernel_name}%nlversion: ${kernel_ver}%nlhead: ${kernel_head}%nldefconfig: ${defconfig}" || true
bash ../tg_utils.sh msg "$RUN_ID: preparing source" || true
bash ../prepare_a3core.sh || exit 1

bash ../tg_utils.sh msg "$RUN_ID: compilation started: $COMPILERS" || true
bash ../build.sh "$COMPILERS" "$PREFIX" || exit 1

shopt -s nullglob
for file in *.log; do
  caption="$RUN_ID: compiler log"
  [ -f "${file}.info" ] && caption="$(cat "${file}.info")"
  bash ../tg_utils.sh up "$file" "$caption" || true
done

for file in *.zip; do
  caption="$RUN_ID: A03 Core build"
  [ -f "${file}.info" ] && caption="$(cat "${file}.info")"
  bash ../tg_utils.sh up "$file" "$caption" || true
  RES=1
done

if [ "${2:-}" = "clean" ]; then
  rm -rf out ../zipper-a3core
fi

exit 0
