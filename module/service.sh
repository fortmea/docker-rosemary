#!/system/bin/sh
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
# Keep Docker bridge routing rules in place (Wi-Fi reconnects recreate tables).
( while true; do sh "$MODDIR/net.sh"; sleep 15; done ) >/dev/null 2>&1 &
# Exempt container UIDs from Android's per-app network allowlists (restricted mode etc.).
mkdir -p /data/docker/log
nohup "$MODDIR/bin/docker-uidfw" >> /data/docker/log/uidfw.log 2>&1 &
sh "$MODDIR/system/bin/dockerctl" start >/dev/null 2>&1
