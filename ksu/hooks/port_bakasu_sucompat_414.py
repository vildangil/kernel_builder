#!/usr/bin/env python3
"""Wire BakaSU/SUSFS su-path probes on rosemary Linux 4.14.

BakaSU's SUSFS variants of stat/faccessat use struct filename **, which
matches newer integrated SUSFS syscall lookup paths, NOT rosemary 4.14's
const char __user * syscall wrappers. Select BakaSU's older userspace-pointer
variant for this kernel, then enable only the matching manual call sites
when CONFIG_KSU_SUSFS is selected. This preserves the original Linux lookup.
Abort on any source-layout change: never guess kernel modifications.
"""
from pathlib import Path


def replace_exact(source: str, before: str, after: str, name: str, count: int = 1) -> str:
    found = source.count(before)
    if found != count:
        raise RuntimeError(f"{name}: expected {count} anchors; got {found}")
    return source.replace(before, after)


def main():
    mk = Path("Makefile").read_text()
    if "VERSION = 4\n" not in mk or "PATCHLEVEL = 14\n" not in mk:
        raise RuntimeError("This BakaSU hook adaptation is only for Linux 4.14")

    su = Path("KernelSU/kernel/feature/sucompat.c")
    src = su.read_text()
    for symbol in ("ksu_handle_faccessat", "ksu_handle_stat"):
        before = f"#ifdef CONFIG_KSU_SUSFS\nint {symbol}(int *dfd, struct filename **filename,"
        after = (f"#if defined(CONFIG_KSU_SUSFS) && "
                 f"LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0)\n"
                 f"int {symbol}(int *dfd, struct filename **filename,")
        src = replace_exact(src, before, after, f"BakaSU {symbol}")
    su.write_text(src)

    # sucompat.h declares the same functions using the newer struct filename
    # signatures whenever SUSFS is selected. Match its ABI to the C file on
    # Linux 4.14 or Clang rejects both definitions with conflicting types.
    header = Path("KernelSU/kernel/feature/sucompat.h")
    header_src = header.read_text()
    header_src = replace_exact(
        header_src,
        "#ifdef CONFIG_KSU_SUSFS\nint ksu_handle_faccessat(",
        "#if defined(CONFIG_KSU_SUSFS) && "
        "LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0)\n"
        "int ksu_handle_faccessat(",
        "BakaSU sucompat.h signatures",
    )
    header.write_text(header_src)

    manual_guard = "#ifdef CONFIG_KSU_MANUAL_HOOK"
    shared_guard = "#if defined(CONFIG_KSU_MANUAL_HOOK) || defined(CONFIG_KSU_SUSFS)"
    op = Path("fs/open.c")
    src = op.read_text()
    src = replace_exact(src, manual_guard, shared_guard, "fs/open.c guards", count=2)
    op.write_text(src)

    stat = Path("fs/stat.c")
    src = stat.read_text()
    src = replace_exact(src,
        manual_guard + "\nextern int ksu_handle_stat(",
        shared_guard + "\nextern int ksu_handle_stat(",
        "fs/stat.c declarations")
    stat_call = (manual_guard + "\n"
                 "\tksu_handle_stat(&dfd, &filename, &flag);\n#endif")
    shared_call = (shared_guard + "\n"
                   "\tksu_handle_stat(&dfd, &filename, &flag);\n#endif")
    src = replace_exact(src, stat_call, shared_call, "fs/stat.c stat calls", count=2)
    stat.write_text(src)

    print("BakaSU 4.14 SUSFS: restored stat/faccessat su probes with compatible ABI")


if __name__ == "__main__":
    main()
