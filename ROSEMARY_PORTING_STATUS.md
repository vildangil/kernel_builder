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

## SUSFS 2.3.0 -- SOURCE PORT STAGED; BUILD UNVERIFIED

The latest failed run (38863218802, 2026-10-16) stops at
`git apply --check` on `fs/notify/fdinfo.c`,
`fs/proc/task_mmu.c`, and `mm/memory.c`.

The new `ksu/sus/port_shadow_susfs.py` preserves the original SUSFS 2.3.0
patch for compatible files, but ports these three files to shadow's procfs
layout with strict source assertions. The port retains the vendor inotify
mask/ignored_mask reporting, adapts fanotify's callback signature,
`show_map_vma` / `smaps` / `smaps_rollup`, and applies the
SUS_MAP access checks to memory.c. The script refuses to change files when
the known vendor source context is absent. It is not intended for arbitrary
Linux 4.14 trees.

This is a *source adaptation*, not proof of successful compilation or
working root hiding. Audit BakaSU/SUSFS compatibility and test on the
device before considering it stable.

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

## BORE 4.2.4 -- SOURCE PORT STAGED; BUILD UNVERIFIED

`ksu/bore/bore-4.14-4.2.4-reference.patch` is copied from the existing
Android 4.14 BORE port:
https://github.com/FlopKernel-Series/flop_trinket-mi_kernel/commit/e8d9c93710c2c8166b72631965ef67fbfa5b62ce

`ksu/bore/port_shadow_bore.py` applies matching upstream hunks and adapts
MTK HMP/WALT-specific divergences in the sched_entity layout, fork path,
CFS tunables, and wakeup enqueue path. A workflow BORE toggle applies
the port **before** compiling (default enabled on the experimental branch).
BORE's scheduler code and sysctls have not yet passed CI or boot tests.
Tuning and potential regressions must be measured before merging.


## BakaSU root/su regression investigation (2026-10-29)

GitHub Actions run 40757808513 on 2026-10-28 built BakaSU v4.2.0-rc3
(commit d5e9e025) and selected **SuSFS Inline hook**. The upstream setup
script failed to checkout missing `sync-susfs` and silently continued on
`main`. Build also warned about `CONFIG_KSU_MANUAL_HOOK` guards remaining
in `fs/open.c` and `fs/stat.c`, despite SUSFS hook mode being active.
Those guards compile out the su existence checks (faccessat/newfstatat)
which root-checking apps often use. SUSFS init success in logcat confirms
neither these checks nor the actual su credential transition.

This experimental branch:
- Defaults to BakaSU main and verifies the requested checkout is real
  (the revision can be pinned with the `KSU_REF` workflow input).
- Selects exactly one hook mode before compiling and checks `out/.config`
  before packaging a ZIP.
- For Linux 4.14 only, compiles the userspace-path variant of BakaSU's
  sucompat stat/faccessat handlers and enables their corresponding 4.14
  syscall call sites in SUSFS mode. The incompatible struct-filename-pointer
  interface is retained for newer kernels.
- Preserves Bluetooth connectivity fix from the base branch.

**Status: source patch staged and inspected, no successful build or on-device
root test for this new branch.** Make a baseline run with BORE=false and
DROIDSPACES=false, KSU=susfs, MTK_CONNECTIVITY=true. Ensure the build reports
`Validated BakaSU SUSFS inline hook mode`; then on a device where the
test application is explicitly allowed by BakaSU, run `su -c id` from a
terminal and verify `uid=0(root)`. Also check apps using stat/access probes.
Keep a working previous boot/kernel ZIP for rollback. Never assume
manager grant alone proves usable root.

## How to validate

Run the workflow from this feature branch using KREPO / KBRANCH defaults:
1. Begin with `KSU` empty, `DROIDSPACES=false`, and `BORE=false` to get a clean baseline.
2. Next enable `DROIDSPACES=true`; inspect `out/.config` and kernel ZIP.
3. Run `KSU=ksu` to validate BakaSU and manual hooks.
4. Only after rebasing SUSFS's rejected hunks, run `KSU=susfs`.
5. Enable `BORE=true` with `KSU=susfs` only after independent KSU/SUSFS testing.
6. Record build output, boot stability, root hiding, and latency/regression results.

**Do not flash kernel artifacts unless the CI build actually produced a
non-empty Image.gz and dtb and kernel/boot compatibility is verified.**
