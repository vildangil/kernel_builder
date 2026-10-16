#!/bin/bash
set -eo pipefail

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/${2:-}env"

[ -z "$NJOBS" ] && export NJOBS=$(nproc --all) || :

pack() {
  if [ ! -d ${zipper} ]; then
    git clone ${zipper_repo} -b ${zipper_branch} "${zipper}" --single-branch --depth=1
    cd "${zipper}" || exit 1
  else
    cd "${zipper}" || exit 1
    git reset --hard
    git checkout ${zipper_branch}
    git fetch origin ${zipper_branch}
    git reset --hard origin/${zipper_branch}
  fi
  
  cp -af "${out_image}" "${zipper}/Image.gz"
  cp -af "${out_dtb}" "${zipper}/dtb"
  
  mkdir -p "${zipper}/modules/system/lib/modules/"
  find "${maindir}/out" -name '*.ko' > module_list.txt
  xargs -r -d '\n' cp -v -t "${zipper}/modules/system/lib/modules/" < module_list.txt
  
  if [ -e ${maindir}/banner_append ]; then
    cat ${maindir}/banner_append >> ${zipper}/banner
    if grep KernelSU ${maindir}/banner_append ; then
      sed -i 's/do.skipmagisk=0/do.skipmagisk=1/g' ${zipper}/anykernel.sh || :
    fi
  fi
  zip -r9 "$1" ./* -x .git README.md ./*placeholder
  if command -v apksigner >/dev/null 2>&1 && [ -n "${SIGN_PK8:-}" ] && [ -n "${SIGN_PEM:-}" ] && [ -f "$SIGN_PK8" ] && [ -f "$SIGN_PEM" ] ; then
    apksigner sign --min-sdk-version 30 --key "$SIGN_PK8" --cert "$SIGN_PEM" "$1" && SIGNED=1
  fi
  rm  -f ${maindir}/banner_append "${out_image}"
  cd "${maindir}"
}

for toolchain in $1; do

  [[ -f "${outside}/toolchains/${toolchain}.sh" ]] || { echo "Unknown toolchain: ${toolchain}" >&2; exit 2; }
  bash -e -o pipefail -x "${outside}/toolchains/${toolchain}.sh" setup

  BUILD_START=$(date +"%s")
  export CUR_TOOLCHAIN="${toolchain}"

  # Some toolchain scripts pipe make into tee and lose make\x27s exit status.
  # Do not mistake an image left from an older build for a fresh success.
  rm -f "${out_image}" "${toolchain}.log"
  bash -e -o pipefail -x "${outside}/toolchains/${toolchain}.sh" build "${defconfig}" || exit 1

  if [ ! -s "${out_image}" ] || [ ! -s "${out_dtb}" ]; then
    echo "Build failed: missing/empty Image.gz or dtb for ${toolchain}" >&2
    exit 1
  fi

  if [[ "${DROIDSPACES:-false}" == "true" ]]; then
    bash "${outside}/configs/validate-droidspaces.sh" "${maindir}/out/.config"
  fi

  if [ -s "${out_image}" ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    pack ${zip_name}
    echo "build succeeded in $((DIFF / 60))m, $((DIFF % 60))s" > "${zip_name}.info"
    echo "md5: <code>$(md5sum "${zip_name}" | cut -d' ' -f1)</code>" >> "${zip_name}.info"
    echo "compiler: $(cat ${toolchain}.info)" >> "${zip_name}.info"
    if [ "$SIGNED" = "1" ] ; then
      echo "signed by <code>apksigner sign --min-sdk-version 30 --key $SIGN_PK8 --cert $SIGN_PEM</code>" >> "${zip_name}.info"
    fi

    echo "build succeeded in $((DIFF / 60))m, $((DIFF % 60))s" > "${toolchain}.log.info"
    echo "ak3 zip file: <code>${zip_name}</code>" >> "${toolchain}.log.info"
    echo "compiler: $(cat ${toolchain}.info)" >> "${toolchain}.log.info"
  else
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    echo "build failed in $((DIFF / 60))m, $((DIFF % 60))s" > "${toolchain}.log.info"
    echo "compiler: $(cat ${toolchain}.info)" >> "${toolchain}.log.info"
  fi
done
