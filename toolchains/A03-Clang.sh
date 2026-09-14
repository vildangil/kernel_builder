#!/bin/bash
# Compiler profile matching the known-good android_kernel_m168 GitHub build.

set -e

maindir="$(pwd)"
outside="${maindir}/.."
clang="${outside}/a03-clang-r383902b"
gcc="${outside}/a03-gcc-14.3"

case "$1" in
  setup)
    mkdir -p "$clang" "$gcc"

    if [ ! -x "$clang/bin/clang" ]; then
      rm -rf "$clang"/*
      wget -q \
        https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/0e9e7035bf8ad42437c6156e5950eab13655b26c/clang-r383902b.tar.gz \
        -O "${outside}/a03-clang.tar.gz"
      tar -xf "${outside}/a03-clang.tar.gz" -C "$clang"
      rm -f "${outside}/a03-clang.tar.gz"
    fi

    if [ ! -x "$gcc/bin/aarch64-none-linux-gnu-gcc" ]; then
      rm -rf "$gcc"/*
      wget -q \
        https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz \
        -O "${outside}/a03-gcc.tar.xz"
      tar -xf "${outside}/a03-gcc.tar.xz" -C "$gcc" --strip-components=1
      rm -f "${outside}/a03-gcc.tar.xz"
    fi
    ;;

  build)
    export PATH="$clang/bin:$gcc/bin:/usr/bin:${PATH}"
    export CROSS_COMPILE="$gcc/bin/aarch64-none-linux-gnu-"
    export CROSS_COMPILE_ARM32="$gcc/bin/arm-none-linux-gnueabihf-"
    export CC=clang

    export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-VildanG}"
    export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-telegram-a3core}"
    export KBUILD_BUILD_TIMESTAMP="$(date -R)"

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
        echo "Unsupported filesystem: $BUILD_FILESYSTEM" >&2
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
      "$gcc/bin/aarch64-none-linux-gnu-gcc" --version | head -n 1
    } | tr '\n' ' ' > "${CUR_TOOLCHAIN}.info"
    ;;

  *)
    echo "usage: $0 {setup|build} [defconfig]" >&2
    exit 2
    ;;
esac
