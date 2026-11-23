# Kernel

**English** · [Português](pt-BR/KERNEL.md)

The LineageOS kernel for rosemary (Linux 4.19, `rosemary_defconfig`) lacks these options.
Without them Docker does not start or cannot create networks:

| Option | Why |
|---|---|
| `CONFIG_SYSVIPC`, `CONFIG_POSIX_MQUEUE`, `CONFIG_IPC_NS` | per-container IPC namespace |
| `CONFIG_CGROUP_PIDS`, `CONFIG_CGROUP_DEVICE` | cgroup controllers required by runc |
| `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE` | iptables rules for published ports |

**The configuration file is [`kernel/docker.config`](../kernel/docker.config)**: a Kconfig
fragment with these options and a few recommended ones, each commented. No code patch is
needed, only configuration. You can download the prebuilt kernel or build it:

- **[Prebuilt](#1c-prebuilt-kernel-from-releases)**: every release ships an `Image.gz` built
  by CI from the `lineage-24.0` branch with this fragment. The fastest path.
- **[Automatic build](#1a-automatic-build-container)**: `kernel/build.sh` downloads the
  source and the compiler, applies the fragment, checks it and builds. The tested path.
- **[Manual build](#1b-manual-build)**: the same steps by hand, on any kernel tree (another
  ROM, another phone, a custom kernel you already use).

## Third-party code used

The script downloads everything from the official sources:

| Component | Source | License |
|---|---|---|
| Kernel | [LineageOS/android_kernel_xiaomi_mt6785](https://github.com/LineageOS/android_kernel_xiaomi_mt6785), branch `lineage-24.0` | GPL-2.0 |
| Clang r416183b (the one LineageOS uses for this phone, `TARGET_KERNEL_CLANG_VERSION`) | [LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b](https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b) | Apache-2.0 with LLVM exception |
| `magiskboot` (repacking boot) | already part of the installed Magisk: `/data/adb/magisk/magiskboot` | GPL-3.0 |

No proprietary components are involved: the boot image you repack is your own phone's, and
its ramdisk, DTB and cmdline are kept.

> **Why only the kernel and not a ready `boot.img`?** Boot contains the ramdisk of your
> LineageOS build and your Magisk; someone else's boot may not boot. Swapping just the kernel
> inside your own boot is safer.

## 1a. Automatic build (container)

Needs ~15 GB free and Docker (on Apple Silicon macOS it runs emulated as amd64, slower:
30 to 90 min). On Linux x86_64 you can run `kernel/build.sh` directly (install the packages
from [`kernel/Dockerfile`](../kernel/Dockerfile) and set `WORK`/`HOST`).

```sh
cd docker-rosemary/kernel
docker build -t rosemary-kernel-builder .
docker run --rm -v rosemary-kernel:/work -v "$PWD":/host rosemary-kernel-builder
```

Result: `kernel/Image.gz` and `kernel/docker.built.config`. The script fails if any option
from the fragment does not end up enabled.

Variables (pass with `-e`): `KERNEL_BRANCH` (default `lineage-24.0`; use the branch of your
LineageOS version), `KERNEL_COMMIT` (optional: a specific commit of that branch) and
`LOCALVERSION` (default `-docker`, shows up in `uname -r`).
Extra patches (`*.patch`) placed in `kernel/patches/` are applied before building.

The `rosemary-kernel` volume keeps sources and objects; rebuilds are incremental and the
script updates the source to the latest commit of the branch (or to `KERNEL_COMMIT`).

## 1b. Manual build

On Linux x86_64 (Ubuntu/Debian; on other systems use the `kernel/Dockerfile` container with
`--entrypoint bash`).

**Dependencies:**

```sh
sudo apt install make bc bison flex libssl-dev libelf-dev python3 cpio kmod git \
    binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi perl xz-utils gzip curl
```

**Source and compiler.** Use the branch of your LineageOS version and the clang the ROM uses
(`TARGET_KERNEL_CLANG_VERSION` in the device's `BoardConfig.mk`; for rosemary, r416183b).
Another clang may build, but it may also produce a kernel that does not boot.

```sh
git clone --depth 1 -b lineage-24.0 https://github.com/LineageOS/android_kernel_xiaomi_mt6785 kernel
git clone --depth 1 -b lineage-20.0 https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b clang
export PATH=$PWD/clang/bin:$PATH
cd kernel
```

**Configuration.** Start from the device defconfig and merge the fragment:

```sh
MK="make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- CLANG_TRIPLE=aarch64-linux-gnu-"
$MK rosemary_defconfig
scripts/kconfig/merge_config.sh -m -O out out/.config /path/to/docker-rosemary/kernel/docker.config
scripts/config --file out/.config --set-str LOCALVERSION -docker
$MK olddefconfig
```

**Check that everything is enabled.** `olddefconfig` *silently* drops options whose
dependencies are not met:

```sh
grep '^CONFIG_' /path/to/docker-rosemary/kernel/docker.config | while read -r l; do
    grep -qxF "$l" out/.config || echo "MISSING: $l"; done
```

If something is missing, run `$MK menuconfig` and search for the option with `/`: the screen
shows what it depends on (`Depends on:`). Enable the dependencies and check again.

Optional: Docker maintains a full checker that classifies each option as required or
optional:

```sh
curl -fsSLO https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh
bash check-config.sh out/.config
```

That script targets regular Linux distributions, so on an Android kernel some options show up
as `missing` without stopping Docker from running (for example storage drivers the module
does not use, or Swarm's `VXLAN`/`IP_VS`). Use it to find what is missing and decide; this
project's criteria are `docker.config` and the
[on-device test checklist](../CONTRIBUTING.md#on-device-test-checklist).

**Build:**

```sh
$MK -j"$(nproc)" Image.gz
ls -l out/arch/arm64/boot/Image.gz
```

**Adapting to another phone or kernel**: swap the repository, branch, defconfig and clang for
your ROM's (all of them are in the device tree's `BoardConfig.mk`: `TARGET_KERNEL_SOURCE`,
`TARGET_KERNEL_CONFIG`, `TARGET_KERNEL_CLANG_VERSION`, `BOARD_KERNEL_IMAGE_NAME`). The
`docker.config` fragment is the same. On 5.x/GKI kernels many options are already on and some
were renamed; `check-config.sh` shows what is missing.

**Alternative without `merge_config.sh`**: append the fragment's lines to the defconfig
(`arch/arm64/configs/rosemary_defconfig`) and run `$MK rosemary_defconfig`. For a running
kernel, `zcat /proc/config.gz > out/.config` is a starting point, but only use it if you are
sure it comes from the same source.

## 1c. Prebuilt kernel from Releases

Every [release](https://github.com/fortmea/docker-rosemary/releases) includes:

| File | Contents |
|---|---|
| `rosemary-docker-Image.gz` | kernel built by the [release workflow](../.github/workflows/release.yml) with the same container as the automatic build |
| `rosemary-docker.config` | the full configuration used (`.config`) |
| `rosemary-docker-kernel.sha256` | SHA-256 of both |
| `rosemary-docker-kernel-COPYING`, `rosemary-docker-kernel-GPL-2.0`, `rosemary-docker-kernel-Linux-syscall-note` | the kernel license, copied from the built tree (the last two from release 29.10.0-5 on) |

The release notes say which `lineage-24.0` commit it was built from. It is meant for LineageOS
24 on rosemary; if your build is much older or newer than that commit, read
[Kernel and vendor modules](#kernel-and-vendor-modules) and, if some hardware fails, build
it yourself from the right commit.

```sh
B=https://github.com/fortmea/docker-rosemary/releases/latest/download
curl -fLO $B/rosemary-docker-Image.gz -fLO $B/rosemary-docker.config -fLO $B/rosemary-docker-kernel.sha256
shasum -a 256 -c rosemary-docker-kernel.sha256
mkdir -p kernel && mv rosemary-docker-Image.gz kernel/Image.gz
```

Continue with step 2 (the commands use `kernel/Image.gz`).

Corresponding source: the LineageOS repository at the commit given in the release notes, plus
`rosemary-docker.config` (see [THIRD_PARTY.md](../THIRD_PARTY.md)).

## 2. Repack boot (on the phone)

The phone is A/B; work with the active slot. These commands keep Magisk's ramdisk, so root
keeps working.

```sh
adb push kernel/Image.gz /data/local/tmp/
adb shell
su
cd /data/local/tmp
S=$(getprop ro.boot.slot_suffix)            # _a or _b
dd if=/dev/block/by-name/boot$S of=boot$S-backup.img
mkdir -p kr && cd kr
/data/adb/magisk/magiskboot unpack ../boot$S-backup.img
/data/adb/magisk/magiskboot decompress ../Image.gz kernel   # replaces the extracted kernel
/data/adb/magisk/magiskboot repack ../boot$S-backup.img ../boot$S-docker.img
cd .. && rm -rf kr
exit; exit
```

`repack` recompresses the kernel in the original format and keeps DTB, ramdisk and cmdline.

**Copy the backup to your computer** before going on (it is what saves the phone if it does
not boot):

```sh
S=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
adb pull /data/local/tmp/boot$S-backup.img
adb pull /data/local/tmp/boot$S-docker.img
```

## 3. Flash

```sh
adb reboot bootloader
fastboot flash boot$S boot$S-docker.img
fastboot reboot
```

Check after it boots:

```sh
adb shell uname -r                                            # contains -docker
adb shell su -c 'zcat /proc/config.gz' | grep -c -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|IPC_NS|CGROUP_PIDS|CGROUP_DEVICE|NETFILTER_XT_MATCH_ADDRTYPE)=y'   # 6
```

Also test Wi-Fi, calls, camera and charging before moving on.

## Revert

If the phone does not boot (or some hardware stops working), enter fastboot (powered off:
**Volume −** + **Power**) and flash the backup:

```sh
fastboot flash boot$S boot$S-backup.img
fastboot reboot
```

## After a LineageOS update

The OTA writes a new boot (with the stock kernel) to the other slot. After updating:

1. Reinstall Magisk on the new boot if you have not yet (Magisk → Install → "Install to
   inactive slot" before rebooting, or the normal method after the update).
2. Download the kernel from the latest release (or rebuild: the script already pulls the
   latest commit of the branch) and repeat steps 2 and 3 with the boot of the new active slot.

Until then the Docker module stays installed, but `dockerd` does not start (see `dockerctl logs`).

## Kernel and vendor modules

The kernel has `CONFIG_MODVERSIONS`; `.ko` modules loaded by the vendor must match the kernel.
Building from the same branch and a commit close to your build's avoids problems. If
something stops working after flashing (Wi-Fi, audio, sensors), revert and build the commit
closest to your build's date (see the history at
[github.com/LineageOS/android_kernel_xiaomi_mt6785/commits/lineage-24.0](https://github.com/LineageOS/android_kernel_xiaomi_mt6785/commits/lineage-24.0)):

```sh
docker run --rm -e KERNEL_COMMIT=<sha> -v rosemary-kernel:/work -v "$PWD":/host rosemary-kernel-builder
```
