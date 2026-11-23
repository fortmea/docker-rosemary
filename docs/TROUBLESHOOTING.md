# Troubleshooting

**English** · [Português](pt-BR/PROBLEMAS.md)

First, collect:

```sh
su
dockerctl status
dockerctl logs 50
tail -20 /data/docker/log/uidfw.log
ip rule show | grep -E '^60(89|10[12]):'
cat /data/docker/resolv.conf
uname -r
```

When opening an issue, paste these outputs ([bug template](https://github.com/fortmea/docker-rosemary/issues/new?template=bug.yml)).

The installer and `dockerctl` print messages in Portuguese; the English meaning is given
next to each one below.

---

### The module installer aborts with "O kernel não tem opções necessárias" (the kernel lacks required options)

The running kernel lacks the listed options. Build or download and flash the kernel as in
[KERNEL.md](KERNEL.md). If you already flashed it and the error remains, check `uname -r`
(it should contain `-docker`): the phone may have booted from the other slot or an OTA
replaced boot.

### `docker: rode como root (su -c docker ...)` (run as root)

`docker` and `dockerctl` only work as root. Run `su` first, or
`su -c 'docker ps'`. In terminal apps, grant the app root in Magisk.

### `Docker não respondeu em 60 s` (Docker did not respond within 60 s)

`dockerd` did not come up. See `dockerctl logs 50`. Common causes:

- **Messages about cgroup, `ipc namespace` or `iptables ... addrtype`**: kernel without the
  options (see above). Common after a LineageOS update.
- **`overlay2` not supported**: check `grep overlay /proc/filesystems`. As a last resort,
  change `"storage-driver": "overlay2"` to `"vfs"` in `/data/docker/daemon.json` (it works,
  but uses far more space; already pulled images must be pulled again).
- **Invalid `daemon.json`** after an edit of yours: validate the JSON. To go back to the
  default: `rm /data/docker/daemon.json && dockerctl start` (it is copied again from the module).

### `dockerd (PID n) existe mas não responde` (dockerd exists but does not respond)

The process hung. `kill -9 <PID>` and `dockerctl start`. If it keeps happening, check the logs.

### Containers have no internet (ping/wget fail) or `network unreachable`

Android drops bridge traffic without the module's routing rules.

1. `ip rule show | grep -E '^60(89|10[12]):'` must list 3 rules. If any is missing, run
   `dockerctl net`. The module re-applies them every 15 s; if they keep disappearing, another
   app/module (VPN, firewall, another container manager) may be touching the rules.
2. Rule `6102` points at the current connection's table. Without an active data/Wi-Fi
   connection it is not created.
3. A Docker network created outside the `172.16.0.0/12` pool (for example
   `--subnet 10.0.0.0/24`) is not covered by the rules. Use subnets inside `172.16.0.0/12` or
   change `POOL` in `/data/adb/modules/docker/net.sh`.
4. An active VPN on Android changes the routing tables; test without it.

### A container with a non-root user has no network (root works)

Images that run with UID ≥ 10000 (for example distroless `nonroot` = 65532) are blocked by
Android's eBPF firewall. `docker-uidfw` allows those UIDs within 3 s.

- `tail /data/docker/log/uidfw.log` should show `allowed uid <n>`.
- If the log says `uid owner map not found` or `unexpected layout`, your Android version has
  a layout uidfw does not know. Open an issue with the output of
  `pm list packages --apex-only --show-versioncode | grep tethering`.
- uidfw never allows UIDs of installed apps; if the container's UID matches an app's, pick
  another one (`user:` in compose).

### DNS failures (`lookup registry-1.docker.io: ... server misbehaving`, `Temporary failure in name resolution`)

- `cat /data/docker/resolv.conf` must have `nameserver` entries. The file is refreshed by
  `net.sh` every 15 s from `dumpsys connectivity`.
- Private DNS (Settings → Network → Private DNS) does not apply to Docker; the public
  fallbacks (1.1.1.1, 8.8.8.8) are used if the network's server fails.
- Networks that block external DNS: set `"dns": ["<ip>"]` in `/data/docker/daemon.json`.

### `x509: certificate signed by unknown authority` when pulling images

- Check the phone's date and time.
- dockerd uses Android's system CAs (`SSL_CERT_DIR` in `nsroot.sh`); CAs installed as
  "user certificates" do not count. If you use a proxy or registry with its own certificate,
  install the CA as a system certificate.

### `exec format error` / `no matching manifest for linux/arm64`

The image only exists for amd64. The kernel has no `BINFMT_MISC`, so QEMU emulation is not
possible. Look for a multi-arch image or build the image for arm64.

### The hotspot / USB tethering stopped working after installing

The module uses `ip-forward-no-drop` so Docker does not change the FORWARD policy. If you
replaced `/data/docker/daemon.json` with your own, keep `"ip-forward-no-drop": true`.

### A published port cannot be reached from another device on the network

- Test on the phone itself: `wget -qO- http://127.0.0.1:<port>`.
- Use the phone's IP on the network (`ip -4 addr show wlan0`).
- Wi-Fi networks with "client isolation" (guest or public networks) block access.

### Docker stops after a while / with the screen off

Android may kill background processes when memory is low. Check
`dmesg | grep -i 'lowmemorykiller\|lmkd'` and `logcat -b events | grep am_kill`. Run fewer
containers or limit their memory (`mem_limit` in compose). The doze firewall rule is
handled by uidfw.

### Docker does not start after updating LineageOS

The OTA installs the stock kernel. Redo [the kernel steps](KERNEL.md#after-a-lineageos-update).

### Low space in `/data`

```sh
docker system df
docker system prune            # stopped containers, networks and unused images
docker system prune -a --volumes   # CAREFUL: also deletes unused volumes
```

### `adb` drops during use

Unstable USB cables/hubs drop the connection. Use ADB over Wi-Fi
(`adb tcpip 5555 && adb connect <ip>:5555`) or a terminal on the phone itself.
Docker keeps running regardless of `adb`.

### Docker networks clash with Droidspaces (`172.28.x.x`)

Since 29.10.0-4 the module's `daemon.json` leaves `172.28.0.0/16` out of Docker's pool.
Installs that started before that keep their old `/data/docker/daemon.json`: copy
`default-address-pools` from `/data/adb/modules/docker/daemon.json` into it and run
`dockerctl restart`.

---

Problem not listed? Open an [issue](https://github.com/fortmea/docker-rosemary/issues/new/choose).
