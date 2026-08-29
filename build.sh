#!/bin/bash
#
# idk lmao

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$2env"

[ -z "$NJOBS" ] && export NJOBS=$(nproc --all) || :

set_debug_config() {
  local cfg="${defconfig_file}"

  if [[ ! -f "${cfg}" ]]; then
    echo "debug: defconfig not found: ${cfg}"
    exit 1
  fi

  set_cfg() {
    local key="$1"
    local value="$2"

    # Remove an existing enabled/disabled entry first so the resulting
    # defconfig contains exactly one value for every debug option.
    sed -i \
      -e "/^${key}=.*/d" \
      -e "/^# ${key} is not set$/d" \
      "${cfg}"

    printf '%s=%s\n' "${key}" "${value}" >> "${cfg}"
  }

  echo "debug: enabling persistent kernel logging in ${cfg}"

  set_cfg CONFIG_PSTORE y
  set_cfg CONFIG_PSTORE_CONSOLE y
  set_cfg CONFIG_PSTORE_PMSG y
  set_cfg CONFIG_PSTORE_RAM y

  set_cfg CONFIG_MTK_RAM_CONSOLE y
  set_cfg CONFIG_MTK_AEE_FEATURE y
  set_cfg CONFIG_MTK_AEE_MRDUMP y

  set_cfg CONFIG_PRINTK y
  set_cfg CONFIG_PRINTK_TIME y
  set_cfg CONFIG_PANIC_TIMEOUT 1

  echo "debug: resulting config entries:"
  grep -E '^(CONFIG_PSTORE|CONFIG_MTK_RAM_CONSOLE|CONFIG_MTK_AEE_FEATURE|CONFIG_MTK_AEE_MRDUMP|CONFIG_PRINTK|CONFIG_PRINTK_TIME|CONFIG_PANIC_TIMEOUT)=' "${cfg}" || :
}

# PATCH_KSU=debug is intentionally a non-KSU build mode.
# The wrapper/workflow only calls build.sh, while this script injects the
# logging options before the toolchain generates out/.config.
if [[ "${PATCH_KSU}" == "debug" ]]; then
  set_debug_config
fi

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
  cp -af "${out_image}" "${zipper}"
  cp -af "${out_dtb}" "${zipper}/dtb"
  find "${maindir}/out" -name '*.ko' > module_list.txt
  xargs -d '\n' cp -v -t "${zipper}/modules/system/lib/modules/" < module_list.txt
  [ -n "${out_dtbo}" ] && cp -af "${out_dtbo}" "${zipper}/dtbo.img"
  if [ -e ${maindir}/banner_append ]; then
    cat ${maindir}/banner_append >> ${zipper}/banner
    if grep KernelSU ${maindir}/banner_append ; then
      sed -i 's/do.skipmagisk=0/do.skipmagisk=1/g' ${zipper}/anykernel.sh || :
    fi
  fi
  zip -r9 "$1" ./* -x .git README.md ./*placeholder
  if apksigner version && [ -f "$SIGN_PK8" ] && [ -f "$SIGN_PEM" ] ; then
    apksigner sign --min-sdk-version 30 --key "$SIGN_PK8" --cert "$SIGN_PEM" "$1" && SIGNED=1
  fi
  rm  -f ${maindir}/banner_append "${out_image}"
  cd "${maindir}"
}

# build
for toolchain in $1; do
  #rm -rf out

  bash -x "${outside}/toolchains/${toolchain}.sh" setup

  BUILD_START=$(date +"%s")
  export CUR_TOOLCHAIN="${toolchain}"

  bash -x "${outside}/toolchains/${toolchain}.sh" build ${defconfig} || exit 1

  if [ -e "${out_image}" ]; then
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
