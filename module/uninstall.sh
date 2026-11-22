#!/system/bin/sh
# Data in /data/docker is kept on purpose; remove it manually if wanted.
sh /data/adb/modules/docker/system/bin/dockerctl stop
sh "${0%/*}/net.sh" clear
