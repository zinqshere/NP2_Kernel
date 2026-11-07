# NP² Kernel

Custom Android kernel build workflow for the **Nothing Phone (2) (Pong)**.

This repository builds flashable AnyKernel3 packages from supported Nothing Phone (2) kernel sources. The build is driven by GitHub Actions and supports multiple kernel variants, KernelSU-Next, optional SUSFS integration, and additional configurable patches.

[![Build NP2 Kernel](https://github.com/zinqshere/NP2_Kernel/actions/workflows/build.yml/badge.svg)](https://github.com/zinqshere/NP2_Kernel/actions/workflows/build.yml)
[![Test All Builds](https://github.com/zinqshere/NP2_Kernel/actions/workflows/build-all.yml/badge.svg)](https://github.com/zinqshere/NP2_Kernel/actions/workflows/build-all.yml)

## Downloads

- **[Latest releases](https://github.com/zinqshere/NP2_Kernel/releases)** — published release builds, when available.
- **[GitHub Actions](https://github.com/zinqshere/NP2_Kernel/actions)** — manually triggered builds and downloadable workflow artifacts.

Build artifacts are retained by GitHub Actions for **30 days**. A successful workflow run does not automatically mean that a GitHub Release has been published.

## Supported kernel variants

The **Test All Builds** workflow runs the following matrix:

| Variant | Source | Branch |
| --- | --- | --- |
| LineageOS | [LineageOS/android_kernel_nothing_sm8475](https://github.com/LineageOS/android_kernel_nothing_sm8475) | `lineage-23.2` |
| NothingOSS | [NothingOSS/android_kernel_msm-5.10_nothing_sm8475](https://github.com/NothingOSS/android_kernel_msm-5.10_nothing_sm8475) | `sm8475/b/mr` |
| arter97 | [arter97/android_kernel_nothing_sm8475](https://github.com/arter97/android_kernel_nothing_sm8475) | `master` |

The variants use different source trees and configuration inputs. Choose the package that matches the ROM/kernel base installed on your device; do not assume the variants are interchangeable.

## Included features and build options

- **[KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)** — kernel-based root solution integrated by the build workflow. When SUSFS is enabled, the workflow fetches the [pershoot SUSFS-integrated KernelSU-Next fork](https://github.com/pershoot/KernelSU-Next) from its `dev-susfs` branch; with SUSFS disabled, it fetches upstream KernelSU-Next.
- **[SUSFS](https://gitlab.com/simonpunk/susfs4ksu)** — optional kernel-side SUSFS support. Enabled by default in the build workflows. The workflow verifies the KernelSU-side SUSFS Kconfig option and applies the matching kernel patch set; it stops rather than packaging a partially patched SUSFS build.
- **[Droidspaces](https://github.com/Droid-OSS/Droidspaces)** — optional compatibility-related kernel configuration and local patches. Enabled for the LineageOS and NothingOSS matrix builds; disabled for arter97.
- **[Baseband Guard (BBG)](https://github.com/vc-teahouse/Baseband-guard)** — optional integration, disabled in the all-build matrix. The workflow warns that enabling BBG may cause bootloops with ReSukiSU/SUSFS; use only when you understand and have tested the compatibility implications.
- **Local patch sets** — repository-managed patches under `patches/` are selected through workflow inputs. The current matrix uses `patches/droidspaces` for LineageOS/NothingOSS and `patches/arter97` for arter97.
- **Consistent kernel version metadata** — builds use the `-zinq` local version suffix and validate the generated kernel release/UTS version against the built image before packaging.
- **AnyKernel3 packaging** — outputs a flashable ZIP for the Nothing Phone (2), using the [AnyKernel3](https://github.com/osm0sis/AnyKernel3) installer framework.

### KPM status

**KPM is not supported by this project build.** The earlier KernelPatch/KPM integration was removed; do not use old README instructions or expect KPM support in these packages.

## Build using GitHub Actions

### Build one kernel

1. Open [Build NP2 Kernel](https://github.com/zinqshere/NP2_Kernel/actions/workflows/build.yml).
2. Select **Run workflow**.
3. Set the source repository, branch, defconfig, and kernel type as required. The defaults target LineageOS 23.2.
4. Choose whether to enable SUSFS, Droidspaces, or BBG. Review the BBG compatibility warning before enabling it.
5. Start the workflow and wait for the build job to complete.
6. Download the generated `kernel-<variant>-NP2-KSUN.zip` from the run's **Artifacts** section.

### Build all supported variants

Open [Test All Builds](https://github.com/zinqshere/NP2_Kernel/actions/workflows/build-all.yml) and select **Run workflow**. It runs the LineageOS, NothingOSS, and arter97 matrix entries independently.

### Build locally

The main build logic is in [Scripts/build_kernel.sh](Scripts/build_kernel.sh), and AnyKernel3 packaging is handled by [Scripts/package_anykernel.sh](Scripts/package_anykernel.sh). The GitHub Actions workflow defines the required toolchain, source checkout, environment variables, patches, and packaging sequence; use [`.github/workflows/build.yml`](.github/workflows/build.yml) as the authoritative build reference.

## Installation

1. Confirm that the ZIP is intended for your Nothing Phone (2) and matches your installed ROM/kernel base.
2. Download the package from [Releases](https://github.com/zinqshere/NP2_Kernel/releases) or from the successful build's Actions artifacts.
3. Keep a copy of your current boot image and a working recovery/restore method before flashing.
4. Flash the ZIP using a compatible custom recovery or the installation method recommended for your setup.
5. Reboot and verify that the device boots and that the expected kernel variant/version is running.

**Important:** Unlocking the bootloader is required for typical custom-kernel flashing and may wipe device data. Kernel flashing always carries a bootloop or data-loss risk. Make a backup first and ensure you know how to restore the stock or previous boot image. Use at your own risk.

The AnyKernel installer identifies the device as **Pong/pong**, targets the boot partition, and declares supported Android versions 13–17. That installer metadata is not a guarantee that every kernel variant or ROM combination has been tested on every Android release.

## Repository layout

```text
.github/workflows/
  build.yml          # Configurable single-kernel build workflow
  build-all.yml      # LineageOS, NothingOSS, and arter97 build matrix
Scripts/
  build_kernel.sh    # Kernel configuration, build, and image validation
  package_anykernel.sh
  anykernel.sh       # AnyKernel3 installer configuration
patches/
  arter97/           # arter97-specific patches
  droidspaces/       # Droidspaces / compatibility patches
CHANGELOG.md         # Project change history
README.md
```

## Project links

- **Repository:** https://github.com/zinqshere/NP2_Kernel
- **Releases:** https://github.com/zinqshere/NP2_Kernel/releases
- **Build one kernel:** https://github.com/zinqshere/NP2_Kernel/actions/workflows/build.yml
- **Build all variants:** https://github.com/zinqshere/NP2_Kernel/actions/workflows/build-all.yml
- **Issues / bug reports:** https://github.com/zinqshere/NP2_Kernel/issues
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)

## Credits and upstream projects

- [LineageOS](https://github.com/LineageOS) — LineageOS kernel source.
- [NothingOSS](https://github.com/NothingOSS) — Nothing kernel source.
- [arter97](https://github.com/arter97) — alternate kernel source and related work.
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) and [pershoot](https://github.com/pershoot/KernelSU-Next) — KernelSU-Next and the SUSFS-integrated fork used for SUSFS builds.
- [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS kernel patches.
- [Droidspaces](https://github.com/Droid-OSS/Droidspaces) — project reference for Droidspaces-related support.
- [Baseband Guard](https://github.com/vc-teahouse/Baseband-guard) — optional BBG integration.
- [osm0sis](https://github.com/osm0sis/AnyKernel3) — AnyKernel3 packaging framework.
- [MiguVT](https://github.com/MiguVT/NP2_Kernel) — original NP2 Kernel project this repository was forked from.

---

Maintained by [zinqshere](https://github.com/zinqshere).
