#!/usr/bin/env bash
set -euo pipefail

cd "${KERNEL_DIR}"

# Do not add a repository-specific LOCALVERSION suffix.
# Let the selected upstream kernel tree generate its native release string.
# Keep the kernel's UTS version timestamp deterministic within this build.
export KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP:-$(date -u '+%a %b %d %H:%M:%S UTC %Y')}"

defconfig_targets=()
defconfig_paths=()
if [ -n "${DEFCONFIG:-}" ]; then
  for def in ${DEFCONFIG}; do
    if echo "${def}" | grep -q '^/'; then
      def_path="${def#/}"
    else
      def_path="arch/arm64/configs/${def}"
    fi

    if [ ! -f "${def_path}" ]; then
      echo "Defconfig path not found: ${def_path}" >&2
      exit 1
    fi

    def_target="$(basename "${def_path}")"
    if [ "${def_path}" != "arch/arm64/configs/${def_target}" ]; then
      cp "${def_path}" "arch/arm64/configs/${def_target}"
    fi

    defconfig_targets+=("${def_target}")
    defconfig_paths+=("arch/arm64/configs/${def_target}")
  done
fi

if [ "${#defconfig_targets[@]}" -lt 1 ]; then
  echo "No defconfig provided" >&2
  exit 1
fi

# Remove stale generated Kbuild metadata from the dedicated output directory.
# MAKE_ARGS includes O=out, so source configuration and applied patches remain intact.
make ${MAKE_ARGS} mrproper

frags=()
if [ -n "${DEFCONFIG_FRAGS:-}" ]; then
  for frag in ${DEFCONFIG_FRAGS}; do
    if [ -f "${frag}" ]; then
      frags+=("${frag}")
    elif [ -f "arch/arm64/configs/${frag}" ]; then
      frags+=("arch/arm64/configs/${frag}")
    else
      echo "Skipping missing defconfig fragment: ${frag}"
    fi
  done
fi

# Remove all generated output before configuring. This prevents stale
# utsrelease.h/utsversion.h and other generated metadata from being reused.
make ${MAKE_ARGS} mrproper

make ${MAKE_ARGS} "${defconfig_targets[0]}"

merge_frags=()
if [ "${#defconfig_paths[@]}" -gt 1 ]; then
  merge_frags+=("${defconfig_paths[@]:1}")
fi
if [ "${#frags[@]}" -gt 0 ]; then
  merge_frags+=("${frags[@]}")
fi

if [ "${#merge_frags[@]}" -gt 0 ]; then
  if [ -x "scripts/kconfig/merge_config.sh" ]; then
    scripts/kconfig/merge_config.sh -m -O out out/.config "${merge_frags[@]}"
  else
    echo "merge_config.sh not found; cannot apply defconfig fragments" >&2
    exit 1
  fi
fi

EXTRA_CFG="out/ci-extra.config"
: > "${EXTRA_CFG}"
echo "CONFIG_KSU=y" >> "${EXTRA_CFG}"

# KernelSU-Next exposes KSU as the driver Kconfig option.
# When SUSFS is enabled, the workflow uses a SUSFS-integrated KernelSU-Next fork
# and applies the matching external SUSFS kernel patch set.
if [ "${SUSFS_SUPPORT}" = "true" ]; then
  echo "CONFIG_KSU_SUSFS=y" >> "${EXTRA_CFG}"
fi

echo "CONFIG_KALLSYMS=y" >> "${EXTRA_CFG}"
echo "CONFIG_KALLSYMS_ALL=y" >> "${EXTRA_CFG}"
echo "CONFIG_KPROBES=y" >> "${EXTRA_CFG}"

if [ "${BBG_SUPPORT}" = "true" ]; then
  echo "CONFIG_BBG=y" >> "${EXTRA_CFG}"
fi

if [ "${DROIDSPACES_SUPPORT}" = "true" ]; then
  echo "CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_IPC_NS=y
CONFIG_PID_NS=y
CONFIG_DEVTMPFS=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_USER_NS=y
CONFIG_NETFILTER_XT_TARGET_REJECT=y
CONFIG_NETFILTER_XT_TARGET_LOG=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y
CONFIG_IP_SET=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y" >> "${EXTRA_CFG}"
fi

cat "${EXTRA_CFG}" >> out/.config
if [ -f version ]; then
  cp version out/version
fi
make ${MAKE_ARGS} olddefconfig

# Fail early if Kconfig silently disabled KSU or a requested SUSFS option.
if ! grep -q '^CONFIG_KSU=y$' out/.config; then
  echo "::error::CONFIG_KSU=y did not survive olddefconfig" >&2
  exit 1
fi
if [ "${SUSFS_SUPPORT}" = "true" ] && ! grep -q '^CONFIG_KSU_SUSFS=y$' out/.config; then
  echo "::error::SUSFS was requested but CONFIG_KSU_SUSFS=y is absent after olddefconfig. Refusing to package a kernel without built-in SUSFS." >&2
  exit 1
fi

# Keep the upstream scripts/setlocalversion implementation unchanged.
# Kbuild will generate the native SCM suffix from the selected source tree.

# Generate the headers (including utsrelease.h) before validating the release.
# kernelrelease can be computed before this header exists, so checking it
# immediately after olddefconfig causes a false failure on a clean output tree.
make ${MAKE_ARGS} prepare

# Verify that Kbuild generated one consistent release identifier before
# compiling it into both init_uts_ns (uname) and the /proc/version banner.
EXPECTED_RELEASE="$(make -s ${MAKE_ARGS} kernelrelease)"
UTSRELEASE_FILE="out/include/generated/utsrelease.h"
if [ ! -s "${UTSRELEASE_FILE}" ] || ! grep -Fq "#define UTS_RELEASE \"${EXPECTED_RELEASE}\"" "${UTSRELEASE_FILE}"; then
  echo "::error::Generated UTS_RELEASE does not match Kbuild kernelrelease (${EXPECTED_RELEASE})." >&2
  [ -f "${UTSRELEASE_FILE}" ] && cat "${UTSRELEASE_FILE}" >&2
  exit 1
fi
echo "Verified kernel release: ${EXPECTED_RELEASE}"
echo "Kernel build timestamp: ${KBUILD_BUILD_TIMESTAMP}"

JOBS=$(( $(nproc) / 2 ))
[ "${JOBS}" -lt 1 ] && JOBS=1
make -j"${JOBS}" ${MAKE_ARGS} Image KCFLAGS="-Wno-error"

IMAGE="out/arch/arm64/boot/Image"
# Linux 5.10 generates UTS_VERSION in compile.h (not utsversion.h).
COMPILE_HEADER="out/include/generated/compile.h"
if [ ! -s "${COMPILE_HEADER}" ]; then
  echo "::error::Missing generated compile header: ${COMPILE_HEADER}" >&2
  exit 1
fi
EXPECTED_UTS_VERSION="$(sed -n 's/^#define UTS_VERSION "\(.*\)"/\1/p' "${COMPILE_HEADER}")"
if [ -z "${EXPECTED_UTS_VERSION}" ]; then
  echo "::error::Could not read generated UTS_VERSION." >&2
  exit 1
fi
if [ ! -s "${IMAGE}" ] || ! grep -aFq "Linux version ${EXPECTED_RELEASE} (" "${IMAGE}"; then
  echo "::error::Built Image banner does not contain expected release ${EXPECTED_RELEASE}." >&2
  exit 1
fi
if ! grep -aFq "${EXPECTED_UTS_VERSION}" "${IMAGE}"; then
  echo "::error::Built Image does not contain generated UTS_VERSION (${EXPECTED_UTS_VERSION})." >&2
  exit 1
fi
echo "Verified Image banner release: ${EXPECTED_RELEASE}"
echo "Verified Image UTS version: ${EXPECTED_UTS_VERSION}"

# Keep a machine-readable release record with the build output. The
# release was already verified against utsrelease.h and the built Image.
VERSION_MANIFEST="out/kernel-version.txt"
{
  printf 'KERNELRELEASE=%s\n' "${EXPECTED_RELEASE}"
  printf 'UTS_VERSION=%s\n' "${EXPECTED_UTS_VERSION}"
  printf 'KERNEL_SOURCE=%s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf 'LOCALVERSION=%s\n' "${LOCALVERSION-}"
} > "${VERSION_MANIFEST}"
