#!/system/bin/sh
# Magisk install-time checks: refuse to install on kernels that can't run Docker.
[ "$ARCH" = arm64 ] || abort "! Apenas arm64 é suportado (este aparelho: $ARCH)"

REQUIRED="NAMESPACES NET_NS PID_NS IPC_NS UTS_NS CGROUPS CGROUP_BPF CGROUP_DEVICE \
CGROUP_FREEZER CGROUP_PIDS KEYS VETH BRIDGE IP_NF_FILTER IP_NF_MANGLE IP_NF_NAT NF_NAT \
IP_NF_TARGET_MASQUERADE NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_MATCH_CONNTRACK \
POSIX_MQUEUE SYSVIPC OVERLAY_FS"

if [ -r /proc/config.gz ]; then
    CFG=$(zcat /proc/config.gz)
    MISSING=""
    for o in $REQUIRED; do
        echo "$CFG" | grep -qE "^CONFIG_$o=(y|m)$" || MISSING="$MISSING $o"
    done
    if [ -n "$MISSING" ]; then
        ui_print "! O kernel não tem opções necessárias para o Docker:"
        for o in $MISSING; do ui_print "!   CONFIG_$o"; done
        abort "! Instalação cancelada. Use um kernel com essas opções."
    fi
    ui_print "- Kernel compatível com Docker."
else
    ui_print "! /proc/config.gz ausente: não foi possível verificar o kernel."
    ui_print "! Instalando assim mesmo; veja /data/docker/log/dockerd.log se falhar."
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/cli-plugins" 0 0 0755 0755
set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755
for f in service.sh uninstall.sh net.sh nsroot.sh common.sh; do set_perm "$MODPATH/$f" 0 0 0755; done

ui_print "- Dados do Docker: /data/docker (mantidos ao desinstalar)"
ui_print "- Após reiniciar: su -c docker ... | su -c dockerctl status"
