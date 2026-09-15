# Samsung Galaxy A03 Core kernel builder

This branch is adapted for Samsung Galaxy A03 Core / m168 / SP9863A and `vildangil/android_kernel_m168`.

## GitHub Actions

Use the **A03 Core Telegram Builder** workflow. Defaults:

- kernel: `https://github.com/vildangil/android_kernel_m168`
- branch: `4.14.199-erofs`
- defconfig: `a3core_eur_open_defconfig`
- compiler: `A03-Clang` (Android clang-r383902b + Arm GNU 14.3 AArch64/ARM32)
- filesystem: `EROFS` or `EXT4`
- root: `ReSukiSU` or `KernelSU-Next`
- optional PM_SYS/CM4 watchdog-off diagnostic
- optional kernel SELinux permissive patch
- AnyKernel3 packaging

Telegram uses repository Actions secrets `BOT_TOKEN` and `CHAT_ID`. `TG_RECIPENT` can override the chat/group id for a run.

Successful runs send the AnyKernel3 zip, compiler log, raw `Image`, and final `.config` to Telegram and also upload them as GitHub Actions artifacts.

## Local build

```bash
cp priv_env.dist priv_env
# edit priv_env if needed
chmod +x run_a3core.sh
./run_a3core.sh
```

`priv_env` is ignored by git and may contain the Telegram bot token/chat id for local notifications.

The local launcher clones/updates the kernel source, integrates the selected root implementation, applies the A03-specific options, builds the Image, creates AnyKernel3, and uploads results to Telegram when credentials are configured.

## Output names

Typical output:

`A03-Core-EROFS-ReSukiSU-<date>-<kernel-head>.zip`

The zip `.info` sidecar includes build time and SHA-256/MD5 hashes.
