#!/bin/bash
#
# idk lmao

export maindir="$(pwd)"
export outside="${maindir}/.."
source "${outside}/$2env"

[ -z "$NJOBS" ] && export NJOBS=$(nproc --all) || :

make_pstore_readonly() {
  local ram="${maindir}/fs/pstore/ram.c"
  local core="${maindir}/fs/pstore/ram_core.c"

  if [[ ! -f "${ram}" || ! -f "${core}" ]]; then
    echo "debug: pstore source files not found"
    echo "debug: expected ${ram}"
    echo "debug: expected ${core}"
    exit 1
  fi

  echo "debug: converting ramoops/persistent_ram to recovery read-only mode"

  python3 - "${ram}" "${core}" <<'PY'
import pathlib
import re
import sys

ram_path = pathlib.Path(sys.argv[1])
core_path = pathlib.Path(sys.argv[2])

ram = ram_path.read_text()
core = core_path.read_text()

def replace_function(text, name, body):
    pat = re.compile(
        r'(?m)^[ \t]*(?:static[ \t]+)?[^\n;{}]*\b' +
        re.escape(name) + r'[ \t]*\('
    )
    m = pat.search(text)
    if not m:
        raise RuntimeError(f"function not found: {name}")

    paren = 0
    seen_paren = False
    brace = None
    i = m.start()
    while i < len(text):
        ch = text[i]
        if ch == '(':
            paren += 1
            seen_paren = True
        elif ch == ')':
            paren -= 1
        elif ch == '{' and seen_paren and paren == 0:
            brace = i
            break
        elif ch == ';' and seen_paren and paren == 0:
            raise RuntimeError(f"matched declaration instead of definition: {name}")
        i += 1

    if brace is None:
        raise RuntimeError(f"opening brace not found: {name}")

    depth = 1
    i = brace + 1
    while i < len(text) and depth:
        ch = text[i]
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
        i += 1

    if depth:
        raise RuntimeError(f"closing brace not found: {name}")

    end_brace = i - 1
    indent_body = "\n".join("\t" + line if line else "" for line in body.splitlines())
    return text[:brace + 1] + "\n" + indent_body + "\n" + text[end_brace:]

# fs/pstore/ram.c
ram = replace_function(
    ram,
    "ramoops_pstore_write",
    "/* Recovery reader: discard every kernel-side pstore write. */\nreturn 0;"
)

ram = replace_function(
    ram,
    "ramoops_pstore_write_user",
    "/* Recovery reader: discard /dev/pmsg0 writes. */\nreturn 0;"
)

ram = replace_function(
    ram,
    "ramoops_pstore_erase",
    "/* Never allow unlink/removal to clear backing persistent RAM. */\nreturn -EROFS;"
)

ram, zap_count = re.subn(
    r'(?m)^[ \t]*persistent_ram_zap\([^;\n]+\);[ \t]*$',
    '\t/* recovery reader: persistent_ram_zap intentionally disabled */',
    ram,
)
if zap_count < 2:
    raise RuntimeError(
        f"expected at least 2 persistent_ram_zap() calls in ram.c, found {zap_count}"
    )

ram = ram.replace(
    'pr_info("attached 0x%lx@0x%llx, ecc: %d/%d\\n",',
    'pr_info("attached 0x%lx@0x%llx, ecc: %d/%d, recovery read-only\\n",',
    1,
)

# Legacy Android /proc/last_kmsg compatibility backed by the already-saved
# previous-boot ramoops console buffer. This adds no second RAM logger.
if '#include <linux/proc_fs.h>' not in ram:
    include_anchor = '#include <linux/of_address.h>\n'
    if include_anchor not in ram:
        raise RuntimeError('ram.c include anchor not found for last_kmsg')
    ram = ram.replace(
        include_anchor,
        include_anchor + '#include <linux/proc_fs.h>\n#include <linux/fs.h>\n',
        1,
    )

last_kmsg_block = r'''
/*
 * Legacy Android compatibility: expose the previous ramoops console as
 * /proc/last_kmsg without creating another persistent RAM logger.
 */
static struct proc_dir_entry *ramoops_last_kmsg_entry;

static ssize_t ramoops_last_kmsg_read(struct file *file, char __user *buf,
                                      size_t count, loff_t *ppos)
{
        struct persistent_ram_zone *prz = oops_cxt.cprz;
        void *old;
        size_t size;

        if (!prz)
                return 0;

        size = persistent_ram_old_size(prz);
        old = persistent_ram_old(prz);
        if (!size || !old)
                return 0;

        return simple_read_from_buffer(buf, count, ppos, old, size);
}

static const struct file_operations ramoops_last_kmsg_fops = {
        .owner  = THIS_MODULE,
        .read   = ramoops_last_kmsg_read,
        .llseek = default_llseek,
};

static void ramoops_register_last_kmsg(void)
{
        if (!oops_cxt.cprz || ramoops_last_kmsg_entry)
                return;

        ramoops_last_kmsg_entry =
                proc_create("last_kmsg", 0440, NULL, &ramoops_last_kmsg_fops);
        if (!ramoops_last_kmsg_entry) {
                pr_warn("failed to create /proc/last_kmsg\n");
                return;
        }

        pr_info("registered /proc/last_kmsg (%zu bytes)\n",
                persistent_ram_old_size(oops_cxt.cprz));
}

static void ramoops_unregister_last_kmsg(void)
{
        if (!ramoops_last_kmsg_entry)
                return;

        remove_proc_entry("last_kmsg", NULL);
        ramoops_last_kmsg_entry = NULL;
}

'''

last_kmsg_anchor = 'static void ramoops_free_przs(struct ramoops_context *cxt)\n'
if last_kmsg_anchor not in ram:
    raise RuntimeError('ram.c ramoops_free_przs anchor not found for last_kmsg')
if 'ramoops_last_kmsg_read' not in ram:
    ram = ram.replace(last_kmsg_anchor, last_kmsg_block + last_kmsg_anchor, 1)

probe_anchor = '''
	/*
	 * Update the module parameter variables as well so they are visible
'''
if probe_anchor not in ram:
    raise RuntimeError('ram.c probe anchor not found for last_kmsg')
if 'ramoops_register_last_kmsg();' not in ram:
    ram = ram.replace(
        probe_anchor,
        '\n\tramoops_register_last_kmsg();\n' + probe_anchor,
        1,
    )

remove_anchor = '\tpstore_unregister(&cxt->pstore);\n'
if remove_anchor not in ram:
    raise RuntimeError('ram.c remove anchor not found for last_kmsg')
if 'ramoops_unregister_last_kmsg();' not in ram:
    ram = ram.replace(
        remove_anchor,
        '\tramoops_unregister_last_kmsg();\n\n' + remove_anchor,
        1,
    )

print('debug: injected /proc/last_kmsg compatibility')

# fs/pstore/ram_core.c
core = replace_function(
    core,
    "persistent_ram_write",
    "/* Recovery reader: report success without touching persistent RAM. */\nreturn count;"
)

core = replace_function(
    core,
    "persistent_ram_write_user",
    "/* Recovery reader: report success without touching persistent RAM. */\nreturn count;"
)

core = replace_function(
    core,
    "persistent_ram_zap",
    "/* Recovery reader: never clear a persistent RAM zone. */\nreturn;"
)

core = replace_function(
    core,
    "persistent_ram_ecc_old",
    "/* Recovery reader: do not perform in-place ECC correction. */\nreturn;"
)

sig_write = "prz->buffer->sig = sig;"
if sig_write not in core:
    raise RuntimeError("persistent RAM signature initialization not found")
core = core.replace(
    sig_write,
    "/* recovery reader: do not initialize persistent RAM signature */",
    1,
)

ram_path.write_text(ram)
core_path.write_text(core)

print(f"debug: patched {ram_path}")
print(f"debug: patched {core_path}")
print(f"debug: removed {zap_count} ramoops zap call(s)")
PY

  echo "debug: read-only pstore source conversion completed"
}

set_debug_config() {
  local cfg="${defconfig_file}"

  if [[ ! -f "${cfg}" ]]; then
    echo "debug: defconfig not found: ${cfg}"
    exit 1
  fi

  set_cfg() {
    local key="$1"
    local value="$2"

    sed -i \
      -e "/^${key}=.*/d" \
      -e "/^# ${key} is not set$/d" \
      "${cfg}"

    printf '%s=%s\n' "${key}" "${value}" >> "${cfg}"
  }

  echo "debug: enabling recovery pstore reader config in ${cfg}"

  set_cfg CONFIG_PSTORE y
  set_cfg CONFIG_PSTORE_RAM y
  set_cfg CONFIG_PSTORE_CONSOLE n
  set_cfg CONFIG_PSTORE_PMSG n
  set_cfg CONFIG_PSTORE_FTRACE n
  set_cfg CONFIG_PROC_FS y
  set_cfg CONFIG_MTK_RAM_CONSOLE n
  set_cfg CONFIG_PRINTK y
  set_cfg CONFIG_PRINTK_TIME y
  set_cfg CONFIG_PANIC_TIMEOUT 0

  echo "debug: resulting config entries:"
  grep -E '^(CONFIG_PSTORE|CONFIG_PROC_FS|CONFIG_MTK_RAM_CONSOLE|CONFIG_PRINTK|CONFIG_PRINTK_TIME|CONFIG_PANIC_TIMEOUT)=' "${cfg}" || :
}

# PATCH_KSU=debug is a non-KSU recovery-reader build.
# Only the temporary cloned kernel source used by this Actions job is modified.
if [[ "${PATCH_KSU}" == "debug" ]]; then
  make_pstore_readonly
  set_debug_config
fi

pack() {
  if [ ! -d ${zipper} ]; then
    git clone ${zipper_repo} -b ${zipper_branch} "${zipper}" --single-branch --depth=1
    cd "${zipper}" || exit 1
  else
    cd "${zipper}" || exit 1
    git reset --hard
    git checkout ${zipper_branch}
    git fetch origin ${zipper_branch}
    git reset --hard origin/${zipper_branch}
  fi
  cp -af "${out_image}" "${zipper}"
  cp -af "${out_dtb}" "${zipper}/dtb"
  find "${maindir}/out" -name '*.ko' > module_list.txt
  xargs -d '\n' cp -v -t "${zipper}/modules/system/lib/modules/" < module_list.txt
  [ -n "${out_dtbo}" ] && cp -af "${out_dtbo}" "${zipper}/dtbo.img"
  if [ -e ${maindir}/banner_append ]; then
    cat ${maindir}/banner_append >> ${zipper}/banner
    if grep KernelSU ${maindir}/banner_append ; then
      sed -i 's/do.skipmagisk=0/do.skipmagisk=1/g' ${zipper}/anykernel.sh || :
    fi
  fi
  zip -r9 "$1" ./* -x .git README.md ./*placeholder
  if apksigner version && [ -f "$SIGN_PK8" ] && [ -f "$SIGN_PEM" ] ; then
    apksigner sign --min-sdk-version 30 --key "$SIGN_PK8" --cert "$SIGN_PEM" "$1" && SIGNED=1
  fi
  rm -f ${maindir}/banner_append "${out_image}"
  cd "${maindir}"
}

# build
for toolchain in $1; do
  #rm -rf out

  bash -x "${outside}/toolchains/${toolchain}.sh" setup

  BUILD_START=$(date +"%s")
  export CUR_TOOLCHAIN="${toolchain}"

  bash -x "${outside}/toolchains/${toolchain}.sh" build ${defconfig} || exit 1

  if [ -e "${out_image}" ]; then
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    pack ${zip_name}
    echo "build succeeded in $((DIFF / 60))m, $((DIFF % 60))s" > "${zip_name}.info"
    echo "md5: <code>$(md5sum "${zip_name}" | cut -d' ' -f1)</code>" >> "${zip_name}.info"
    echo "compiler: $(cat ${toolchain}.info)" >> "${zip_name}.info"
    if [ "$SIGNED" = "1" ] ; then
      echo "signed by <code>apksigner sign --min-sdk-version 30 --key $SIGN_PK8 --cert $SIGN_PEM</code>" >> "${zip_name}.info"
    fi

    echo "build succeeded in $((DIFF / 60))m, $((DIFF % 60))s" > "${toolchain}.log.info"
    echo "ak3 zip file: <code>${zip_name}</code>" >> "${toolchain}.log.info"
    echo "compiler: $(cat ${toolchain}.info)" >> "${toolchain}.log.info"
  else
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    echo "build failed in $((DIFF / 60))m, $((DIFF % 60))s" > "${toolchain}.log.info"
    echo "compiler: $(cat ${toolchain}.info)" >> "${toolchain}.log.info"
  fi
done
