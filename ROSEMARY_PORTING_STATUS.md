# Rosemary kernel porting status (Linux 4.14.186 / non-GKI)

This branch is a **work in progress**, not a confirmed flashable kernel.
Target kernel: https://github.com/vildangil/android_kernel_xiaomi_evolution/tree/shadow
Base builder branch: `Rosemary`.

## Investigated CI failure

The 2026-10-03 build (GitHub Actions run 37151683499) reported success despite
an unsuccessful kernel build and no ZIP. The reason is the workflow
`bash ../build.sh "$COMPILERS" || true`, combined with toolchain
`make ... | tee` without `pipefail`. The actual log contains:

- `You lost ksu_handle_setresuid hook in your kernel`
- `*** You should integrate ReSukiSU in your kernel`
- failed/rejected hunks in `fs/open.c`, `fs/notify/fdinfo.c`,
  `fs/proc/task_mmu.c`, `fs/proc_namespace.c` and `fs/stat.c`
- conflicting patches: the legacy and test SUSFS ports both modify `fs/Makefile`.

The CI/build-script changes ensure future build and patch failures stop the
workflow and collect log / reject artifacts, instead of producing false success.

## BakaSU

`ksu/setup_bakasu.sh` now uses the upstream BakaSU setup script:
https://github.com/Baka-SU/BakaSU/blob/main/kernel/setup.sh

`ksu/ksu.sh` and `ksu/susfs.sh` run this installation. These are
**not verified by a kernel build**. Manual syscall/input hook backport to
4.14 is still required; the Rosemary hook patch may not satisfy current BakaSU.

## SUSFS 2.3.0 -- NOT FIXED

Previously the build indiscriminately applied both SUSFS `*.patch` files.
The new script selects only one candidate
(`ksu/sus/test-susfs.patch`, overridable via `SUSFS_PATCH`), performs
`git apply --check`, and stops on any reject.

The candidate still requires an audited source-level port to Linux 4.14.186.
Original `ksu/sus/susfs-v2.3.0.txt` and older patch remain for reference,
but are **not** blindly applied.

## DroidSpaces -- CONFIGURATION PREPARED

Workflow has a `DROIDSPACES` toggle (enabled by default in this branch).
`configs/enable-droidspaces.sh` enables kernel namespaces, cgroups,
seccomp, network virtualization, and applies a kernel/cgroup compatibility
patch adapted from DroidSpaces' non-GKI patch 02. It checks key symbols in the
resulting Kconfig.

Upstream source:
https://github.com/ravindu644/Droidspaces-OSS/tree/main/Documentation/resources/kernel-patches/non-GKI

Upstream patch 01 targets `net/netfilter/xt_qtaguid.c`, which is absent from
the target kernel; that patch is therefore not applied here. DroidSpaces
container startup and network behavior **require on-device verification**.

## BORE -- NOT PORTED

An older Android-specific BORE port targeting a Linux 4.14 derivative exists:
https://github.com/FlopKernel-Series/flop_trinket-mi_kernel/commit/e8d9c93710c2c8166b72631965ef67fbfa5b62ce

It modifies at least:
- `include/linux/sched.h` and `include/linux/sched/task.h`
- `init/Kconfig` and `kernel/fork.c`
- `kernel/sched/core.c`, `kernel/sched/debug.c`, `kernel/sched/fair.c`
- `kernel/sysctl.c`

Compared against Rosemary's 4.14.186 `shadow` sources, many hunks differ
(particularly `kernel/sched/fair.c`). Porting those scheduling invariants
requires a deliberate rebase plus boot/latency testing. This branch does NOT
enable `CONFIG_SCHED_BORE` or pretend the port is working.

## How to validate

Run the workflow from this feature branch using KREPO / KBRANCH defaults:
1. Begin with `KSU` empty and `DROIDSPACES=false` to get a clean baseline.
2. Next enable `DROIDSPACES=true`; inspect `out/.config` and kernel ZIP.
3. Run `KSU=ksu` to validate BakaSU and manual hooks.
4. Only after rebasing SUSFS's rejected hunks, run `KSU=susfs`.
5. Port BORE separately and compare performance without introducing regressions.

**Do not flash kernel artifacts unless the CI build actually produced a
non-empty Image.gz and dtb and kernel/boot compatibility is verified.**
