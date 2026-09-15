#!/bin/bash
# Generic builder flow adapted for Samsung Galaxy A03 Core (m168)

set -euo pipefail

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/env"

[ -z "${NJOBS:-}" ] && export NJOBS="$(nproc --all)" || :
SIGNED=0

pack() {
  local output_zip="$1"

  if [ ! -d "${zipper}/.git" ]; then
    rm -rf "${zipper}"
    git clone "${zipper_repo}" -b "${zipper_branch}" "${zipper}" --single-branch --depth=1
  else
    cd "${zipper}"
    git reset --hard
    git fetch origin "${zipper_branch}" --depth=1
    git checkout "${zipper_branch}"
    git reset --hard "origin/${zipper_branch}"
    cd "${maindir}"
  fi

  cp -af "${out_image}" "${zipper}/Image"

  cd "${zipper}"
  sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh
  sed -i "s/kernel.string=.*/kernel.string=A03-Core-${BUILD_FILESYSTEM}-${ROOT_SOLUTION} by VildanG/g" anykernel.sh
  sed -i 's|BLOCK=.*|BLOCK=auto;|g' anykernel.sh
  sed -i 's/IS_SLOT_DEVICE=.*/IS_SLOT_DEVICE=0;/g' anykernel.sh
  sed -i '/# init.rc/,/append_file fstab.tuna.*/d' anykernel.sh

  rm -f "${output_zip}"
  zip -r9 "${output_zip}" . -x '.git/*' '.github/*' 'README.md'

  if command -v apksigner >/dev/null 2>&1 && \
     [ -n "${SIGN_PK8:-}" ] && [ -n "${SIGN_PEM:-}" ] && \
     [ -f "$SIGN_PK8" ] && [ -f "$SIGN_PEM" ]; then
    apksigner sign --min-sdk-version 30 --key "$SIGN_PK8" --cert "$SIGN_PEM" "$output_zip"
    SIGNED=1
  fi

  cd "${maindir}"
}

for toolchain in ${1:-A03-Clang}; do
  bash -x "${outside}/toolchains/${toolchain}.sh" setup

  BUILD_START=$(date +"%s")
  export CUR_TOOLCHAIN="${toolchain}"

  set +e
  bash -x "${outside}/toolchains/${toolchain}.sh" build "${defconfig}"
  RET=$?
  set -e

  if [ "$RET" -ne 0 ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    {
      echo "build failed in $((DIFF / 60))m, $((DIFF % 60))s"
      echo "device: Samsung Galaxy A03 Core (m168/sp9863a)"
      echo "filesystem: ${BUILD_FILESYSTEM}"
      echo "root: ${ROOT_SOLUTION}"
      [ -f "${toolchain}.info" ] && echo "compiler: $(cat "${toolchain}.info")"
    } > "${toolchain}.log.info"
    exit "$RET"
  fi

  if [ ! -s "${out_image}" ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    echo "build failed: Image was not produced after $((DIFF / 60))m, $((DIFF % 60))s" > "${toolchain}.log.info"
    exit 1
  fi

  BUILD_END=$(date +"%s")
  DIFF=$((BUILD_END - BUILD_START))
  pack "${zip_name}"

  {
    echo "build succeeded in $((DIFF / 60))m, $((DIFF % 60))s"
    echo "device: Samsung Galaxy A03 Core (m168/sp9863a)"
    echo "filesystem: ${BUILD_FILESYSTEM}"
    echo "root: ${ROOT_SOLUTION}"
    echo "kernel sha256: <code>$(sha256sum "${out_image}" | cut -d' ' -f1)</code>"
    echo "zip sha256: <code>$(sha256sum "${zip_name}" | cut -d' ' -f1)</code>"
    echo "zip md5: <code>$(md5sum "${zip_name}" | cut -d' ' -f1)</code>"
    [ -f "${toolchain}.info" ] && echo "compiler: $(cat "${toolchain}.info")"
    [ "$SIGNED" = "1" ] && echo "signed by apksigner"
  } > "${zip_name}.info"

  {
    echo "build succeeded in $((DIFF / 60))m, $((DIFF % 60))s"
    echo "ak3 zip file: <code>$(basename "${zip_name}")</code>"
    echo "filesystem: ${BUILD_FILESYSTEM}"
    echo "root: ${ROOT_SOLUTION}"
    [ -f "${toolchain}.info" ] && echo "compiler: $(cat "${toolchain}.info")"
  } > "${toolchain}.log.info"
done
