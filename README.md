# Docker on Xiaomi rosemary

**English** · [Português](README.pt-BR.md) · [Homepage](https://fortmea.github.io/docker-rosemary/)

The official Docker Engine and Docker Compose running natively on the **Redmi Note 10S / Poco M5s
(codename `rosemary`, MediaTek Helio G95 / MT6785)** with LineageOS and root. No Termux,
no chroot, no virtual machine.

The project has two parts:

| Part | What it is | Where |
|---|---|---|
| **Kernel** | The stock LineageOS kernel lacks a few options Docker needs. There is a config fragment, a script that builds the kernel from the official LineageOS source, and a prebuilt kernel in every release. | [`kernel/`](kernel/), [docs/KERNEL.md](docs/KERNEL.md) |
| **Magisk module** | Official static Docker binaries (`download.docker.com`) + Compose + scripts that adapt Docker to Android (mount namespace, routing, DNS, eBPF firewall). | [`module/`](module/), [`uidfw/`](uidfw/) |

The module zip and the prebuilt kernel are in [Releases](https://github.com/fortmea/docker-rosemary/releases).
Once installed, the module gets updates through the Magisk app itself.

**MMRL:** add the repository `https://fortmea.github.io/docker-rosemary/` in
[MMRL](https://github.com/MMRLApp/MMRL) (Repositories → Add) to install and update from there.

## Status

Tested on the device with:

- LineageOS 24 (nightly 2026-11-04), A/B slots
- Magisk 31.1 (the module also detects KernelSU and APatch)
- LineageOS kernel `4.19.325` (`lineage-24.0`) + [`kernel/docker.config`](kernel/docker.config)
- Docker Engine 29.10.0, Compose v5.8.0: arm64 images, bridge networks, published ports,
  volumes, `docker compose`, Portainer, Nextcloud AIO

## Quick start

> Requires an unlocked bootloader, LineageOS and a working Magisk.
> Swapping the kernel can leave the phone unbootable if done wrong: **back up boot first**.
> Follow the full guide in [docs/INSTALL.md](docs/INSTALL.md).

1. Check whether the running kernel already works (usually it does **not** on stock LineageOS):
   ```sh
   adb shell su -c 'zcat /proc/config.gz' | grep -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|IPC_NS|CGROUP_PIDS|CGROUP_DEVICE|NETFILTER_XT_MATCH_ADDRTYPE)='
   ```
   If any of the 6 lines is missing, flash a kernel with the options in
   [`kernel/docker.config`](kernel/docker.config): the prebuilt `rosemary-docker-Image.gz`
   from Releases, or one you build yourself (container script or by hand). See
   [docs/KERNEL.md](docs/KERNEL.md).
2. Download `docker-magisk-<version>.zip` from Releases (or install it from MMRL) and install
   it in the Magisk app (Modules → Install from storage). The installer refuses incompatible
   kernels.
3. Reboot and test:
   ```sh
   adb shell
   su
   dockerctl status
   docker run --rm hello-world
   ```

## Usage

All commands run as root (`su`):

| Command | Purpose |
|---|---|
| `docker ...`, `docker compose ...` | the regular Docker CLI |
| `dockerctl start\|stop\|restart` | controls `dockerd` |
| `dockerctl status` | state and running containers |
| `dockerctl logs [n]` | last lines of `/data/docker/log/dockerd.log` |
| `dockerctl net` | re-applies the routing rules (also done every 15 s) |

Files on the device:

- `/data/docker/lib`: images, volumes, containers (kept when the module is uninstalled)
- `/data/docker/daemon.json`: daemon configuration (copied from the module only the first time)
- `/data/docker/log/`: `dockerd.log`, `uidfw.log`
- `/data/docker/run/docker.sock`: the socket on Android. Containers see the standard path
  `/var/run/docker.sock`, so ordinary compose files (Portainer etc.) work unchanged.

Published ports (`-p 8080:80`) are reachable on the phone's IP on the local network.
The daemon does not listen on TCP by default. To control it over the network, add a `tcp://`
host **with TLS** to `/data/docker/daemon.json` (see the
[Docker documentation](https://docs.docker.com/engine/security/protect-access/)).

## How it works

Android is not a regular Linux distribution. The module bridges the differences like this:

- **Read-only root**: `nsroot.sh` runs `dockerd` in a private mount namespace
  (`unshare -m`) whose root mirrors Android's (rbind) plus writable `/run`, `/var/run` and
  `/etc` (`dockerd` hardcodes `/run/docker` and needs `/etc/resolv.conf`).
  Nothing changes in Android's own namespace.
- **cgroup v2**: if Android does not mount cgroup2 at `/sys/fs/cgroup`, it is mounted inside
  Docker's namespace.
- **Policy routing**: Android drops traffic forwarded from bridges (`32000: unreachable`).
  `net.sh` adds `ip rule` entries for `172.16.0.0/12` (Docker's address pool) pointing at the
  active connection's table and re-applies them every 15 s (Wi-Fi reconnects recreate the
  tables). The pool leaves out `172.28.0.0/16`, Droidspaces' default NAT range, so both can
  run side by side.
- **DNS**: `net.sh` keeps `/data/docker/resolv.conf` filled with the current network's DNS
  servers (`dumpsys connectivity`) plus public fallbacks.
- **Per-UID eBPF firewall**: Android blocks traffic from any UID ≥ 10000 that is not an
  allowed app (restricted networking, background, doze). Container processes running as,
  say, UID 65532 end up offline. `docker-uidfw` ([`uidfw/`](uidfw/)) sets the permission bits
  in netd's `uid_owner_map` only for UIDs of processes inside the `docker` cgroup, never for
  UIDs of installed apps.
- **Hotspot / tethering**: `ip-forward-no-drop` in `daemon.json` stops Docker from switching
  the FORWARD policy to DROP, which would break the hotspot.
- **Certificates**: `SSL_CERT_DIR` points at Android's CA store.

## Known limitations

- **arm64** images only (`linux/arm64`). The kernel has no `BINFMT_MISC`, so there is no amd64
  emulation through QEMU.
- Docker Swarm / overlay networks do not work (`VXLAN`, `IP_VS` are missing).
- LineageOS OTA updates replace boot and **remove the custom kernel**. Redo the kernel step
  after every update ([docs/KERNEL.md](docs/KERNEL.md#after-a-lineageos-update)).
- Other arm64 phones may work (nothing in the module is rosemary-specific), but only rosemary
  is tested.
- Messages from the installer and `dockerctl` are in Portuguese.

## Documentation

- [Full installation](docs/INSTALL.md)
- [Kernel: download, build, flash and revert](docs/KERNEL.md)
- [Updating Docker](docs/UPDATING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)
- [Third-party code and licenses](THIRD_PARTY.md)

Portuguese versions: [docs/pt-BR/](docs/pt-BR/).

## License

Scripts and code in this repository: [MIT](LICENSE). Docker, Compose and the kernel are
third-party software with their own licenses; see [THIRD_PARTY.md](THIRD_PARTY.md).
Unofficial project, not affiliated with Docker Inc., Xiaomi or LineageOS.
