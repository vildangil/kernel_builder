#!/usr/bin/env python3
"""Checked BORE 4.2.4 port for evolution/shadow Linux 4.14 (MTK/WALT).

The reference 4.14 commit uses a different Android vendor scheduler.
Apply clean hunks verbatim; adapt the conflicting vendor-specific hunks
explicitly, failing if the expected source layout has changed.
"""
import pathlib
import re
import sys

SKIP = {
    "include/linux/sched.h": {0},
    "include/linux/sched/task.h": set(),
    "init/Kconfig": set(),
    "kernel/fork.c": set(),
    "kernel/sched/core.c": {1},
    "kernel/sched/debug.c": set(),
    "kernel/sched/fair.c": {1, 2, 3, 6, 7},
    "kernel/sysctl.c": {0},
}


def once(src, orig, result, path):
    n = src.count(orig)
    if n != 1:
        raise RuntimeError(f"{path}: expected one occurrence of {orig[:100]!r}; got {n}")
    return src.replace(orig, result, 1)


def hunks(patch, path):
    marker = f"diff --git a/{path} b/{path}\n"
    if patch.count(marker) != 1:
        raise RuntimeError(f"{path}: missing or repeated diff")
    block = patch.split(marker, 1)[1].split("\ndiff --git a/", 1)[0]
    ret = []
    current = None
    for line in block.splitlines(keepends=True):
        if line.startswith("@@ "):
            current = []
            ret.append(current)
        elif current is not None and line[:1] in (" ", "-", "+"):
            current.append(line)
    return ret


def patch_clean(src, patch, path):
    excluded = SKIP[path]
    for num, h in enumerate(hunks(patch, path)):
        old = "".join(line[1:] for line in h if line[0] in " -")
        new = "".join(line[1:] for line in h if line[0] in " +")
        if num in excluded:
            if old in src:
                raise RuntimeError(f"{path}: previously diverged hunk {num} unexpectedly matches")
            continue
        src = once(src, old, new, path)
    return src


def sched_h(src):
    path = "include/linux/sched.h"
    fields = """#ifdef CONFIG_SCHED_BORE
    u64                burst_time;
    u8                 prev_burst_penalty;
    u8                 curr_burst_penalty;
    u8                 burst_penalty;
    u8                 burst_score;
    u8                 child_burst;
    u32                child_burst_cnt;
    u64                child_burst_last_cached;
#endif /* CONFIG_SCHED_BORE */
""".replace("    ", "\t")
    return once(src, "\tu64\t\t\t\tprev_sum_exec_runtime;\n",
                "\tu64\t\t\t\tprev_sum_exec_runtime;\n" + fields, path)


def core(src):
    path = "kernel/sched/core.c"
    # Keep the exported type compatible with the fair.c definition.
    src = once(src, "extern bool sched_bore;", "extern uint sched_bore;", path)
    anchor = "\tINIT_LIST_HEAD(&p->se.group_node);\n"
    return once(src, anchor,
                "#ifdef CONFIG_SCHED_BORE\n\tsched_fork_bore(p);\n#endif\n" + anchor,
                path)


def wrap_tunable(src, regex, bore_declaration, path):
    matches = list(re.finditer(regex, src, re.MULTILINE))
    if len(matches) != 1:
        raise RuntimeError(f"{path}: expected one tunable matching {regex}, got {len(matches)}")
    old = matches[0].group()
    return src[:matches[0].start()] + (
        "#ifdef CONFIG_SCHED_BORE\n" + bore_declaration +
        "#else\n" + old + "#endif /* CONFIG_SCHED_BORE */\n"
    ) + src[matches[0].end():]


def fair(src, patch):
    path = "kernel/sched/fair.c"
    src = wrap_tunable(src,
        r"^unsigned int sysctl_sched_latency\s*=\s*6000000ULL;\n"
        r"unsigned int normalized_sysctl_sched_latency\s*=\s*6000000ULL;\n",
        "unsigned int sysctl_sched_latency = 24000000ULL;\n"
        "unsigned int normalized_sysctl_sched_latency = 24000000ULL;\n",
        path)
    src = wrap_tunable(src,
        r"^enum sched_tunable_scaling sysctl_sched_tunable_scaling\s*=\s*SCHED_TUNABLESCALING_LOG;\n",
        "enum sched_tunable_scaling sysctl_sched_tunable_scaling = SCHED_TUNABLESCALING_NONE;\n",
        path)
    src = wrap_tunable(src,
        r"^unsigned int sysctl_sched_min_granularity\s*=\s*750000ULL;\n"
        r"unsigned int normalized_sysctl_sched_min_granularity\s*=\s*750000ULL;\n",
        "unsigned int sysctl_sched_min_granularity = 3000000ULL;\n"
        "unsigned int normalized_sysctl_sched_min_granularity = 3000000ULL;\n",
        path)
    src = wrap_tunable(src,
        r"^unsigned int sysctl_sched_wakeup_granularity\s*=\s*1000000UL;\n"
        r"unsigned int normalized_sysctl_sched_wakeup_granularity\s*=\s*1000000UL;\n",
        "unsigned int sysctl_sched_wakeup_granularity = 4000000UL;\n"
        "unsigned int normalized_sysctl_sched_wakeup_granularity = 4000000UL;\n",
        path)
    # Extract scheduler penalty helpers from the pinned reference patch.
    patch_additions = "".join(line[1:] for line in hunks(patch, path)[3] if line.startswith("+"))
    match = re.search(
        r"#ifdef CONFIG_SCHED_BORE\nuint __read_mostly sched_bore\b.*?"
        r"#endif // CONFIG_SCHED_BORE\n", patch_additions, re.DOTALL)
    if not match:
        raise RuntimeError("BORE helper block missing from reference patch")
    declarations = match.group()
    anchor = "const_debug unsigned int sysctl_sched_migration_cost\t= 33000UL;\n"
    src = once(src, anchor, anchor + "\n" + declarations, path)

    # ENQUEUE_WAKEUP is the flag seen on this vendor's enqueue path;
    # DEQUEUE_SLEEP is not meaningful as an independent enqueue flag.
    anchor = "\tint task_new = !(flags & ENQUEUE_WAKEUP);\n"
    src = once(src, anchor, anchor + """#ifdef CONFIG_SCHED_BORE
    bool task_waking = flags & ENQUEUE_WAKEUP;
#endif
""".replace("    ", "\t"), path)
    anchor = "\tfor_each_sched_entity(se) {\n\t\tif (se->on_rq)\n\t\t\tbreak;\n"
    # This sequence appears in enqueue_task_fair; other occurrences differ.
    src = once(src, anchor, """#ifdef CONFIG_SCHED_BORE
    if (task_waking) {
        cfs_rq = cfs_rq_of(se);
        if (cfs_rq->curr == se)
            update_curr(cfs_rq);
        restart_burst(se);
    }
#endif

""".replace("    ", "\t") + anchor, path)
    return src


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: port_shadow_bore.py /path/to/bore-4.14-4.2.4-reference.patch")
    patch = pathlib.Path(sys.argv[1]).read_text()
    new_contents = {}
    for name in SKIP:
        path = pathlib.Path(name)
        original = path.read_text()
        result = patch_clean(original, patch, name)
        if name == "include/linux/sched.h":
            result = sched_h(result)
        elif name == "kernel/sched/core.c":
            result = core(result)
        elif name == "kernel/sched/fair.c":
            result = fair(result, patch)
        if result == original:
            raise RuntimeError(f"{name}: no change")
        new_contents[path] = result
    # Stage all changes only after the entire source layout passes validation.
    for path, data in new_contents.items():
        path.write_text(data)
        print(f"BORE 4.2.4 shadow port: patched {path}")


if __name__ == "__main__":
    main()
