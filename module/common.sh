# Shared by the module scripts: busybox from whichever root solution is installed.
for BB in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox; do
    [ -x "$BB" ] && break
done
[ -x "$BB" ] || { echo "busybox não encontrado (Magisk, KernelSU ou APatch)" >&2; exit 1; }
