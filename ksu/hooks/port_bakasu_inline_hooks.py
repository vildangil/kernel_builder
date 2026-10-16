#!/usr/bin/env python3
"""Backport required BakaSU SUSFS inline hook entry points to shadow/4.14.

The BakaSU SUSFS mode differs from manual-hook mode. Its Kbuild checks
require direct setresuid, sys_read and input hooks even on NonGKI 4.14.
Keep original syscall security and return paths unchanged.
"""
from pathlib import Path


def patch_file(name, substitutions):
    path = Path(name)
    original = path.read_text()
    modified = original
    for old, new in substitutions:
        count = modified.count(old)
        if count != 1:
            raise RuntimeError(f"{name}: expected one source anchor {old[:90]!r}, got {count}")
        modified = modified.replace(old, new, 1)
    if modified == original:
        raise RuntimeError(f"{name}: empty patch")
    path.write_text(modified)
    print(f"BakaSU 4.14 inline hooks: patched {name}")


def main():
    guard = "#ifdef CONFIG_KSU_SUSFS\n"
    footer = "#endif /* CONFIG_KSU_SUSFS */\n"
    setuid_proto = guard + "extern int ksu_handle_setresuid(uid_t ruid, uid_t euid, uid_t suid);\n" + footer
    read_proto = (guard + "extern int ksu_handle_sys_read(unsigned int fd,\n"
                  "                                  char __user **buf_ptr, size_t *count_ptr);\n" + footer)
    input_proto = (guard + "extern int ksu_handle_input_handle_event(unsigned int *type,\n"
                   "                                         unsigned int *code, int *value);\n" + footer)

    patch_file("kernel/sys.c", [
        ("SYSCALL_DEFINE3(setresuid, uid_t, ruid, uid_t, euid, uid_t, suid)\n",
         setuid_proto + "SYSCALL_DEFINE3(setresuid, uid_t, ruid, uid_t, euid, uid_t, suid)\n"),
        ("\tkuid_t kruid, keuid, ksuid;\n\n",
         "\tkuid_t kruid, keuid, ksuid;\n\n" + guard +
         "\tksu_handle_setresuid(ruid, euid, suid);\n" + footer + "\n"),
    ])

    patch_file("fs/read_write.c", [
        ("SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)\n",
         read_proto + "SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)\n"),
        ("\tstruct fd f = fdget_pos(fd);\n\tssize_t ret = -EBADF;\n\n",
         "\tstruct fd f = fdget_pos(fd);\n\tssize_t ret = -EBADF;\n\n" + guard +
         "\tksu_handle_sys_read(fd, &buf, &count);\n" + footer + "\n"),
    ])

    patch_file("drivers/input/input.c", [
        ("void input_event(struct input_dev *dev,\n",
         input_proto + "void input_event(struct input_dev *dev,\n"),
        ("\tunsigned long flags;\n\n\tif (is_event_supported(type, dev->evbit, EV_MAX)) {\n",
         "\tunsigned long flags;\n\n" + guard +
         "\tksu_handle_input_handle_event(&type, &code, &value);\n" + footer +
         "\n\tif (is_event_supported(type, dev->evbit, EV_MAX)) {\n"),
    ])

    # The exec and reboot manual-hook functions keep the same signatures in
    # BakaSU's inline SUSFS mode, unlike stat/faccessat (see below).
    old_guard = "#ifdef CONFIG_KSU_MANUAL_HOOK"
    new_guard = "#if defined(CONFIG_KSU_MANUAL_HOOK) || defined(CONFIG_KSU_SUSFS)"
    for name, expected in [("fs/exec.c", 3), ("kernel/reboot.c", 2)]:
        path = Path(name)
        source = path.read_text()
        seen = source.count(old_guard)
        if seen != expected:
            raise RuntimeError(f"{name}: expected {expected} manual guards, got {seen}")
        path.write_text(source.replace(old_guard, new_guard))
        print(f"BakaSU 4.14 inline hooks: broadened {seen} guards in {name}")

    # BakaSU's inline SUSFS stat/faccessat handlers use struct filename **
    # rather than the const char __user ** of manual mode. Never unguard
    # their existing call sites without porting the lookup API as well.


if __name__ == "__main__":
    main()
