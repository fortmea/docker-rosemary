#!/system/bin/sh
# Runs inside a private mount namespace (unshare -m). Builds a root that mirrors
# Android's / plus writable /run and /var/run (dockerd hardcodes /run/docker/plugins,
# and the Android root fs is read-only), pivots into it and execs dockerd.
# Everything is rbind-ed from the real root, so /data, /sys, /proc... are the same
# filesystems; only /run, /var and /etc are built for Docker.
set -e
M=${0%/*}
. "$M/common.sh"
D=${DOCKER_DIR:-/data/docker}
R=$D/rootfs

$BB mount --make-rslave /
$BB mount -t tmpfs -o mode=0755 docker-root "$R"
for p in /*; do
    n=${p#/}
    case "$n" in etc|run|var) continue ;; esac
    if [ -L "$p" ]; then
        ln -s "$(readlink "$p")" "$R/$n"
    elif [ -d "$p" ]; then
        mkdir "$R/$n" && $BB mount -o rbind "$p" "$R/$n"
    else
        touch "$R/$n" && $BB mount -o bind "$p" "$R/$n"
    fi
done
# /data was rbind-ed after $R was mounted, so it holds a copy of $R; drop it.
$BB umount -l "$R$R" 2>/dev/null || true

# /etc: links to every entry of Android's /etc plus resolv.conf (maintained by net.sh).
ETC=$(readlink -f /etc)
mkdir "$R/etc"
for e in "$ETC"/*; do ln -s "$e" "$R/etc/${e##*/}"; done
ln -sf "$D/resolv.conf" "$R/etc/resolv.conf"
mkdir "$R/run" "$R/var" "$R/.oldroot"
ln -s /run "$R/var/run"

# Docker needs cgroup2 at /sys/fs/cgroup; Android < 12 mounts it elsewhere (or not at all).
if ! grep -q ' /sys/fs/cgroup cgroup2 ' /proc/mounts; then
    $BB mount -t cgroup2 none "$R/sys/fs/cgroup"
fi

cd "$R"
$BB pivot_root . .oldroot
cd /
$BB umount -l /.oldroot
rmdir /.oldroot

export PATH="$M/bin:/system/bin"
# Android's CA store (Android 14+ keeps it in the conscrypt APEX).
export SSL_CERT_DIR=/apex/com.android.conscrypt/cacerts:/system/etc/security/cacerts
exec dockerd --config-file "$D/daemon.json"
