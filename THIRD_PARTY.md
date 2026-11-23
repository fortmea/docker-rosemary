# Third-party code

**English** · [Português](THIRD_PARTY.pt-BR.md)

This repository contains only scripts, the `docker-uidfw` source and documentation
([MIT](LICENSE) license). No third-party binary is committed: they are downloaded from the
official sources at build time, with SHA-256 pinned in [`versions.env`](versions.env), or
built by CI from the official source.

## Included in the module zip (releases)

| Component | Files in the zip | Source | License |
|---|---|---|---|
| Docker Engine (Moby), CLI, `docker-proxy` | `bin/dockerd`, `bin/docker`, `bin/docker-proxy` | [download.docker.com/linux/static/stable/aarch64](https://download.docker.com/linux/static/stable/aarch64/) · code: [moby/moby](https://github.com/moby/moby), [docker/cli](https://github.com/docker/cli) | Apache-2.0 ([text](licenses/Apache-2.0.txt), [NOTICE](licenses/NOTICE-moby.txt)) |
| containerd, `ctr`, shim | `bin/containerd`, `bin/ctr`, `bin/containerd-shim-runc-v2` | same tgz · [containerd/containerd](https://github.com/containerd/containerd) | Apache-2.0 |
| runc | `bin/runc` | same tgz · [opencontainers/runc](https://github.com/opencontainers/runc) | Apache-2.0 |
| tini | `bin/docker-init` | same tgz · [krallin/tini](https://github.com/krallin/tini) | MIT ([text](licenses/MIT-tini.txt)) |
| Docker Compose | `cli-plugins/docker-compose` | [docker/compose releases](https://github.com/docker/compose/releases) | Apache-2.0 |
| docker-uidfw | `bin/docker-uidfw` | built from [`uidfw/`](uidfw/) with the Go standard library ([BSD license](https://go.dev/LICENSE)) | MIT |

The license texts ship inside the zip under `licenses/`. "Docker" is a trademark of Docker,
Inc.; this project is not affiliated with or endorsed by it.

## Prebuilt kernel (releases)

| Component | Files in the release | Corresponding source | License |
|---|---|---|---|
| LineageOS Linux kernel for MT6785 | `rosemary-docker-Image.gz`, `rosemary-docker.config` | [LineageOS/android_kernel_xiaomi_mt6785](https://github.com/LineageOS/android_kernel_xiaomi_mt6785), branch `lineage-24.0`, at the commit given in the release notes, with the configuration `rosemary-docker.config` (= `rosemary_defconfig` + [`kernel/docker.config`](kernel/docker.config)); built by [`kernel/build.sh`](kernel/build.sh) | GPL-2.0 with the Linux syscall note (`rosemary-docker-kernel-COPYING`, `-GPL-2.0` and `-Linux-syscall-note` in the release) |

## Used, but not redistributed

| Component | Use | Source | License |
|---|---|---|---|
| Clang r416183b | kernel compiler | [LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b](https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b) | Apache-2.0 with LLVM exception |
| Ubuntu 22.04 + build packages | image of the build container ([`kernel/Dockerfile`](kernel/Dockerfile)) | Docker Hub `ubuntu` | various (free) |
| Magisk / `magiskboot` | root and boot repacking | [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | GPL-3.0 |
| LineageOS | the phone's OS | [lineageos.org](https://lineageos.org) | Apache-2.0 and others |

## Proprietary components

No proprietary component is needed or distributed. The repacked boot is the user's own
phone's (ramdisk, DTB and cmdline are kept); vendor firmware and blobs stay the ones that
came with the installed ROM. Unlocking the bootloader requires Xiaomi's official Mi Unlock
tool, obtained directly from Xiaomi.

If you distribute an `Image.gz`/`boot.img` you built, GPL-2.0 requires offering the
corresponding source: point to the LineageOS commit used and to the configuration, as this
project's releases do.
