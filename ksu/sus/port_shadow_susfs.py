#!/usr/bin/env python3
"""Port SUSFS 2.3.0 patch hunks to Xiaomi evolution/shadow Linux 4.14.

The published patch is for a different 4.14 procfs layout.  All other
files are patched with git apply; this program ports only the three
files excluded from that application. Every expected context is checked.
"""
import pathlib
import re
import sys

PORT = {
    "fs/notify/fdinfo.c": {3},
    "fs/proc/task_mmu.c": {0, 1, 3, 4, 5},
    "mm/memory.c": {0},
}


def replace_once(text, old, new, file):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{file}: expected one instance of {old[:90]!r}, got {count}")
    return text.replace(old, new, 1)


def section_hunks(patch, path):
    marker = f"diff --git a/{path} b/{path}\n"
    if patch.count(marker) != 1:
        raise RuntimeError(f"cannot uniquely identify {path} patch")
    part = patch.split(marker, 1)[1].split("\ndiff --git a/", 1)[0]
    hunks = []
    current = None
    for line in part.splitlines(keepends=True):
        if line.startswith("@@ "):
            current = []
            hunks.append(current)
        elif current is not None and line[:1] in (" ", "-", "+"):
            current.append(line)
        elif line.startswith("\\ No newline"):
            continue
    return hunks


def apply_clean_hunks(text, patch, path):
    expected = PORT[path]
    failures = set()
    for i, hunk in enumerate(section_hunks(patch, path)):
        old = "".join(line[1:] for line in hunk if line[0] in " -")
        new = "".join(line[1:] for line in hunk if line[0] in " +")
        if i in expected:
            if old in text:
                raise RuntimeError(f"{path}: expected source divergence at hunk {i} not found")
            failures.add(i)
            continue
        text = replace_once(text, old, new, path)
    if failures != expected:
        raise RuntimeError(f"{path}: expected diverged hunks {expected}, got {failures}")
    return text


def port_fdinfo(text):
    path = "fs/notify/fdinfo.c"
    # The shadow tree keeps the upstream inotify mask and ignored_mask fields.
    # Don't overwrite those with the older patch's ignored_mask:0 format.
    code = """#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
        if (susfs_is_current_app_uid()) {
            bool is_fuse = false;

            if (susfs_is_inode_sus_kstat(inode, &is_fuse)) {
                unsigned long ino = inode->i_ino;
                dev_t dev = inode->i_sb->s_dev;
                u32 mask = mark->mask & IN_ALL_EVENTS;

                susfs_sus_kstat_spoof_inotify_fdinfo(&ino, &dev);
                seq_printf(m, "inotify wd:%x ino:%lx sdev:%x mask:%x ignored_mask:%x ",
                           inode_mark->wd, ino, dev, mask, mark->ignored_mask);
                show_mark_fhandle(m, inode);
                seq_putc(m, '\\n');
                iput(inode);
                return;
            }
        }
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
        if (susfs_is_current_proc_umounted()) {
            struct mount *mnt = real_mount(file->f_path.mnt);

            if (mnt->mnt_id >= DEFAULT_KSU_MNT_ID) {
                struct path path;
                char *pathname = kmalloc(PAGE_SIZE, GFP_KERNEL);

                if (pathname) {
                    char *dpath = d_path(&file->f_path, pathname, PAGE_SIZE);

                    if (!IS_ERR(dpath) && !kern_path(dpath, 0, &path)) {
                        struct inode *real_inode = d_backing_inode(path.dentry);

                        if (real_inode) {
                            u32 mask = mark->mask & IN_ALL_EVENTS;

                            seq_printf(m, "inotify wd:%x ino:%lx sdev:%x mask:%x ignored_mask:%x ",
                                       inode_mark->wd, real_inode->i_ino,
                                       real_inode->i_sb->s_dev, mask, mark->ignored_mask);
                            show_mark_fhandle(m, real_inode);
                            seq_putc(m, '\\n');
                            path_put(&path);
                            kfree(pathname);
                            iput(inode);
                            return;
                        }
                        path_put(&path);
                    }
                    kfree(pathname);
                }
            }
        }
#endif
""".replace("        ", "\t")
    needle = "\tinode = igrab(mark->connector->inode);\n\tif (inode) {\n"
    text = replace_once(text, needle, needle + code, path)
    # Fanotify uses the same dispatch helper; keep its callback signature in
    # sync with the SUSFS-aware show_fdinfo implementation.
    orig = "static void fanotify_fdinfo(struct seq_file *m, struct fsnotify_mark *mark)\n{\n"
    adapted = """#if defined(CONFIG_KSU_SUSFS_SUS_MOUNT) || defined(CONFIG_KSU_SUSFS_SUS_KSTAT)
static void fanotify_fdinfo(struct seq_file *m, struct fsnotify_mark *mark,
                           struct file *file)
{
    (void)file;
#else
static void fanotify_fdinfo(struct seq_file *m, struct fsnotify_mark *mark)
{
#endif
"""
    text = replace_once(text, orig, adapted, path)
    text = replace_once(text, "#include <linux/exportfs.h>\n", "#include <linux/exportfs.h>\n#include <linux/slab.h>\n", path)
    return text


def port_task_mmu(text):
    path = "fs/proc/task_mmu.c"
    include = "#include <linux/mm_inline.h>\n"
    text = replace_once(text, include, include + """#if defined(CONFIG_KSU_SUSFS_SUS_KSTAT) || defined(CONFIG_KSU_SUSFS_SUS_MAP) || defined(CONFIG_KSU_SUSFS_OPEN_REDIRECT)
#include <linux/susfs_def.h>
#endif
""", path)

    declarations = """#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
extern void susfs_sus_kstat_spoof_show_map_vma(struct inode *inode,
                                               dev_t *out_dev, unsigned long *out_ino);
#endif
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
extern struct srcu_struct susfs_srcu_open_redirect;
extern int susfs_open_redirect_spoof_show_map_vma_srcu(
    struct inode *inode, unsigned long *out_ino, dev_t *out_dev,
    char **out_spoofed_name);
#endif

"""
    text = replace_once(text, "static void\nshow_map_vma(", declarations + "static void\nshow_map_vma(", path)

    # This tree uses split-out smap_gather_stats() and __show_smap(), not
    # the monolithic show_smap(..., is_pid) used by the original patch.
    text = replace_once(text, "\tmemset(&mss, 0, sizeof(mss));\n\n\tsmap_gather_stats(vma, &mss);\n",
        """#ifdef CONFIG_KSU_SUSFS_SUS_MAP
    if (vma->vm_file && SUSFS_IS_INODE_SUS_MAP(file_inode(vma->vm_file)))
        return 0;
#endif
    memset(&mss, 0, sizeof(mss));

    smap_gather_stats(vma, &mss);
""".replace("    ", "\t"), path)
    # Also omit SUS_MAP regions from smaps_rollup accounting.
    text = replace_once(text, "\tfor (vma = priv->mm->mmap; vma;) {\n\t\tsmap_gather_stats(vma, &mss);\n",
        """\tfor (vma = priv->mm->mmap; vma;) {
#ifdef CONFIG_KSU_SUSFS_SUS_MAP
        if (!vma->vm_file ||
            !SUSFS_IS_INODE_SUS_MAP(file_inode(vma->vm_file)))
#endif
            smap_gather_stats(vma, &mss);
""".replace("        ", "\t").replace("            ", "\t\t\t"), path)
    return text


def port_memory(text):
    path = "mm/memory.c"
    return replace_once(text, "#include <asm/pgtable.h>\n",
        "#include <asm/pgtable.h>\n\n#ifdef CONFIG_KSU_SUSFS_SUS_MAP\n#include <linux/susfs_def.h>\n#endif\n",
        path)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: port_shadow_susfs.py /path/to/test-susfs.patch")
    patch = pathlib.Path(sys.argv[1]).read_text()
    methods = {
        "fs/notify/fdinfo.c": port_fdinfo,
        "fs/proc/task_mmu.c": port_task_mmu,
        "mm/memory.c": port_memory,
    }
    pending = {}
    for name, method in methods.items():
        path = pathlib.Path(name)
        original = path.read_text()
        modified = method(apply_clean_hunks(original, patch, name))
        if modified == original:
            raise RuntimeError(f"{name}: no changes; unexpected source")
        pending[path] = modified
    # Don't write anything unless every target has passed its source assertions.
    for path, data in pending.items():
        path.write_text(data)
        print(f"SUSFS 2.3.0 shadow port: patched {path}")


if __name__ == "__main__":
    main()
