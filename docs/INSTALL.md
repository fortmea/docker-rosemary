# Installation

**English** · [Português](pt-BR/INSTALACAO.md)

## Requirements

| Item | Notes |
|---|---|
| Redmi Note 10S / Poco M5s (`rosemary`) | `adb shell getprop ro.product.device` must print `rosemary` |
| Unlocked bootloader | via Mi Unlock (Xiaomi's tool, out of scope for this project) |
| LineageOS | tested with LineageOS 24; install it with the [official guide](https://wiki.lineageos.org/devices/rosemary/) |
| Root | Magisk ≥ 20.4 (tested 31.1). KernelSU and APatch are detected but untested |
| Computer | `adb` and `fastboot` ([platform-tools](https://developer.android.com/tools/releases/platform-tools)); Docker or Linux x86_64 only if you build the kernel |
| Space | ~250 MB for the module + whatever your images take in `/data` |

## 1. A compatible kernel

Check the required options in the running kernel:

```sh
adb shell su -c 'zcat /proc/config.gz' | grep -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|IPC_NS|CGROUP_PIDS|CGROUP_DEVICE|NETFILTER_XT_MATCH_ADDRTYPE)='
```

All 6 lines must show `=y`. Stock LineageOS lacks them: follow [KERNEL.md](KERNEL.md) to
download the prebuilt kernel from Releases (or build it) and flash it, then come back here.

## 2. Magisk module

**Option A: release zip (recommended)**

1. Download `docker-magisk-<version>.zip` and its `.sha256` from
   [Releases](https://github.com/fortmea/docker-rosemary/releases) and verify:
   `shasum -a 256 -c docker-magisk-*.zip.sha256`
2. Copy it to the phone: `adb push docker-magisk-*.zip /sdcard/Download/`
3. Magisk → Modules → Install from storage → pick the zip.
   From the command line instead: `adb shell su -c 'magisk --install-module /sdcard/Download/docker-magisk-<version>.zip'`
4. Reboot.

New versions show up in Magisk → Modules (**Update** button) starting with 29.10.0-4.
If you have 29.10.0-3, install the new zip by hand once.

**Option B: MMRL**

In [MMRL](https://github.com/MMRLApp/MMRL), go to Repositories → Add and enter
`https://fortmea.github.io/docker-rosemary/`. The **Docker** module then shows up in the
module list and MMRL handles installs and updates.

**Option C: build the zip**

Requirements on the computer: `bash`, `curl`, `tar`, `zip` and Go (the version in [`uidfw/go.mod`](../uidfw/go.mod)).

```sh
git clone https://github.com/fortmea/docker-rosemary
cd docker-rosemary
scripts/build-module.sh          # downloads official Docker/Compose and checks SHA-256
# result: out/docker-magisk-<version>.zip
```

Install it as in option A.

## 3. Verify

```sh
adb shell
su
dockerctl status            # "Docker rodando (PID ...)"
docker info | head -20
docker run --rm hello-world
docker run --rm alpine wget -qO- https://example.com | head -3   # network + DNS + TLS
```

If something fails, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## 4. Example: Portainer

```sh
su
mkdir -p /data/docker/compose/portainer && cd /data/docker/compose/portainer
cat > compose.yaml <<'EOF'
services:
  portainer:
    image: portainer/portainer-ce:lts
    restart: unless-stopped
    ports: ["9443:9443"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
volumes:
  portainer_data:
EOF
docker compose up -d
```

Open `https://<phone-ip>:9443` in a browser. Containers with
`restart: unless-stopped` come back on their own after the phone reboots.

## Uninstall

Remove the module in Magisk and reboot. `/data/docker` (images, volumes, configuration) is
kept on purpose. To delete everything:

```sh
su -c 'rm -rf /data/docker'
```

To go back to the original kernel, flash the boot backup (see [KERNEL.md](KERNEL.md#revert)).
