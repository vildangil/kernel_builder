#!/bin/bash
# Compiler profile matching the known-good android_kernel_m168 GitHub build.

set -e

maindir="$(pwd)"
outside="${maindir}/.."
clang="${outside}/a03-clang-r383902b"
gcc64="${outside}/a03-gcc64-14.3"
gcc32="${outside}/a03-gcc32-14.3"

fetch_archive() {
  local url="$1"
  local out="$2"
  local kind="$3"
  local i

  for i in 1 2 3 4 5; do
    rm -f "$out"
    echo "Downloading $(basename "$out") (attempt $i/5)..."
    if wget --timeout=60 --tries=2 --retry-connrefused -O "$out" "$url"; then
      case "$kind" in
        tgz)
          if tar -tzf "$out" >/dev/null 2>&1; then
            return 0
          fi
          ;;
        txz)
          if tar -tJf "$out" >/dev/null 2>&1; then
            return 0
          fi
          ;;
      esac
    fi
    echo "Archive download/verification failed, retrying..." >&2
    sleep $((i * 3))
  done

  echo "Failed to download a valid archive from $url" >&2
  return 1
}

case "$1" in
  setup)
    mkdir -p "$clang" "$gcc64" "$gcc32"

    if [ ! -x "$clang/bin/clang" ]; then
      rm -rf "$clang"/*
      fetch_archive \
        https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/0e9e7035bf8ad42437c6156e5950eab13655b26c/clang-r383902b.tar.gz \
        "${outside}/a03-clang.tar.gz" tgz
      tar -xzf "${outside}/a03-clang.tar.gz" -C "$clang"
      rm -f "${outside}/a03-clang.tar.gz"
    fi

    if [ ! -x "$gcc64/bin/aarch64-none-linux-gnu-gcc" ]; then
      rm -rf "$gcc64"/*
      fetch_archive \
        https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz \
        "${outside}/a03-gcc64.tar.xz" txz
      tar -xJf "${outside}/a03-gcc64.tar.xz" -C "$gcc64" --strip-components=1
      rm -f "${outside}/a03-gcc64.tar.xz"
    fi

    if [ ! -x "$gcc32/bin/arm-none-linux-gnueabihf-gcc" ]; then
      rm -rf "$gcc32"/*
      fetch_archive \
        https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz \
        "${outside}/a03-gcc32.tar.xz" txz
      tar -xJf "${outside}/a03-gcc32.tar.xz" -C "$gcc32" --strip-components=1
      rm -f "${outside}/a03-gcc32.tar.xz"
    fi
    ;;

  build)
    export PATH="$clang/bin:$gcc64/bin:$gcc32/bin:/usr/bin:${PATH}"
    export CROSS_COMPILE="$gcc64/bin/aarch64-none-linux-gnu-"
    export CROSS_COMPILE_ARM32="$gcc32/bin/arm-none-linux-gnueabihf-"
    export CC=clang

    export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-VildanG}"
    export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-a3core-builder}"
    export KBUILD_BUILD_TIMESTAMP="$(date -u -R)"

    rm -rf out
    make O=out ARCH=arm64 "$2"

    chmod +x scripts/config
    scripts/config --file out/.config -e KSU
    scripts/config --file out/.config -e KSU_MANUAL_HOOK

    case "${ROOT_SOLUTION:-ReSukiSU}" in
      ReSukiSU)
        scripts/config --file out/.config -d KSU_TRACEPOINT_HOOK || true
        scripts/config --file out/.config -d KSU_SUSFS || true
        ;;
      KernelSU-Next)
        scripts/config --file out/.config -d KSU_KPROBES_HOOK || true
        ;;
      *)
        echo "Unsupported ROOT_SOLUTION=${ROOT_SOLUTION}" >&2
        exit 2
        ;;
    esac

    case "${BUILD_FILESYSTEM:-EROFS}" in
      EROFS)
        scripts/config --file out/.config -e EROFS_FS
        scripts/config --file out/.config -e EROFS_FS_XATTR
        scripts/config --file out/.config -e EROFS_FS_POSIX_ACL
        scripts/config --file out/.config -e EROFS_FS_SECURITY
        scripts/config --file out/.config -e EROFS_FS_ZIP
        scripts/config --file out/.config -e EROFS_FS_ARMV8_ACCELERATED_LZ4
        scripts/config --file out/.config --set-val EROFS_FS_CLUSTER_PAGE_LIMIT 1
        ;;
      EXT4)
        scripts/config --file out/.config -e EXT4_FS
        scripts/config --file out/.config -e EXT4_FS_POSIX_ACL
        scripts/config --file out/.config -e EXT4_FS_SECURITY
        scripts/config --file out/.config -e EXT4_ENCRYPTION
        scripts/config --file out/.config -e EXT4_FS_ENCRYPTION
        scripts/config --file out/.config -d EROFS_FS
        scripts/config --file out/.config -d EROFS_FS_XATTR || true
        scripts/config --file out/.config -d EROFS_FS_POSIX_ACL || true
        scripts/config --file out/.config -d EROFS_FS_SECURITY || true
        scripts/config --file out/.config -d EROFS_FS_ZIP || true
        scripts/config --file out/.config -d EROFS_FS_ARMV8_ACCELERATED_LZ4 || true
        ;;
      *)
        echo "Unsupported BUILD_FILESYSTEM=${BUILD_FILESYSTEM}" >&2
        exit 2
        ;;
    esac

    make O=out ARCH=arm64 olddefconfig

    echo "===== KernelSU config ====="
    grep -E '^CONFIG_KSU|^# CONFIG_KSU' out/.config || true
    echo "===== Filesystem config ====="
    grep -E '^CONFIG_(EROFS|EXT4)|^# CONFIG_(EROFS|EXT4)' out/.config || true

    # Old vendor DTC cannot build the YAML helpers with modern hosts.
    sed -i '/yamltree.o/d' scripts/dtc/Makefile
    sed -i '/dt_to_yaml/d' scripts/dtc/dtc.c

    set -o pipefail
    make O=out -j"${NJOBS:-$(nproc --all)}" \
      ARCH=arm64 CC=clang \
      CROSS_COMPILE="$CROSS_COMPILE" \
      CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
      Image 2>&1 | tee "${CUR_TOOLCHAIN}.log"

    test -s out/arch/arm64/boot/Image
    {
      "$clang/bin/clang" --version | head -n 1
      "$gcc64/bin/aarch64-none-linux-gnu-gcc" --version | head -n 1
      "$gcc32/bin/arm-none-linux-gnueabihf-gcc" --version | head -n 1
    } | tr '\n' ' ' > "${CUR_TOOLCHAIN}.info"
    ;;

  *)
    echo "usage: $0 {setup|build} [defconfig]" >&2
    exit 2
    ;;
esac
