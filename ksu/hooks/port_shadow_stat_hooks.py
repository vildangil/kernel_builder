#!/usr/bin/env python3
"""Apply BakaSU manual stat hooks after SUSFS 2.3.0 on shadow Linux 4.14.

The two independent patch sets both insert declarations after asm/unistd.h.
Apply all syscall entry/return hooks using the exact snippets in the
reference patch, but insert the declarations without assuming that the next
line is the original generic_fillattr() comment.
"""
import pathlib
import re
import sys


def unique_replace(data, old, new, where):
    found = data.count(old)
    if found != 1:
        raise RuntimeError(f"{where}: expected one patch target, found {found}")
    return data.replace(old, new, 1)


def load_hunks(raw, name):
    marker = f"diff --git a/{name} b/{name}\n"
    if raw.count(marker) != 1:
        raise RuntimeError(f"{name}: missing or duplicated source patch")
    section = raw.split(marker, 1)[1].split("\ndiff --git a/", 1)[0]
    ret = []
    for s in re.split(r"(?=^@@ -\d)", section, flags=re.M):
        if not s.startswith("@@ "):
            continue
        lines = s.splitlines(keepends=True)
        hdr = lines[0]
        text = [line for line in lines[1:] if line[:1] in (" ", "-", "+")]
        ret.append((hdr, text))
    return ret


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: port_shadow_stat_hooks.py <test_resukisu_hooks.patch>")
    src = pathlib.Path("fs/stat.c")
    source = src.read_text()
    patch = pathlib.Path(sys.argv[1]).read_text()
    hunks = load_hunks(patch, "fs/stat.c")
    if len(hunks) != 5:
        raise RuntimeError(f"unexpected BakaSU stat patch layout ({len(hunks)} hunks)")

    header, lines = hunks[0]
    expected_intro = " #include <asm/unistd.h>\n"
    if expected_intro not in lines:
        raise RuntimeError("unexpected stat hook include context")
    declarations = "".join(line[1:] for line in lines if line.startswith("+"))
    if "ksu_handle_stat" not in declarations or "ksu_handle_fstat64_ret" not in declarations:
        raise RuntimeError("incomplete BakaSU stat declarations")
    source = unique_replace(source,
        "#include <asm/unistd.h>\n",
        "#include <asm/unistd.h>\n\n" + declarations,
        "fs/stat.c (prototypes)")

    # Individual syscall symbols disambiguate otherwise-identical hunks in
    # newfstatat and fstatat64.  Preserve the rest of SUSFS's modified stat.c.
    for num, (header, lines) in enumerate(hunks[1:], 1):
        symbol = re.search(r"SYSCALL_DEFINE[0-9]+\([A-Za-z_0-9]+", header)
        if symbol is None:
            raise RuntimeError(f"hunk {num}: no syscall anchor")
        symbol = symbol.group()
        if source.count(symbol) != 1:
            raise RuntimeError(f"hunk {num}: syscall {symbol} missing or ambiguous")
        start = source.index(symbol)
        stop = source.find("\nSYSCALL_DEFINE", start + len(symbol))
        if stop < 0:
            stop = len(source)
        function = source[start:stop]
        old = "".join(line[1:] for line in lines if line[0] in " -")
        new = "".join(line[1:] for line in lines if line[0] in " +")
        if not old or not new:
            raise RuntimeError(f"hunk {num}: empty patch")
        updated = unique_replace(function, old, new, f"fs/stat.c ({symbol})")
        source = source[:start] + updated + source[stop:]

    src.write_text(source)
    print("BakaSU: manual stat syscalls composed with SUSFS 2.3.0")


if __name__ == "__main__":
    main()
