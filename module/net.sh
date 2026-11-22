#!/system/bin/sh
# Android policy routing for Docker bridge networks.
# Without these rules forwarded traffic from the bridges hits "32000: unreachable".
# Covers the whole Docker address pool (daemon.json default-address-pools: 172.16.0.0/12
# minus 172.28.0.0/16), so new networks work without per-subnet fixes.
# 172.28.0.0/16 is left out of the pools because it is Droidspaces' NAT range; Droidspaces
# installs its own rules at prefs 6090-6100, which take precedence over the ones below.
POOL=172.16.0.0/12
IP=/system/bin/ip

ensure() { # ensure <pref> <expected text from 'ip rule show'> <ip rule add args...>
    pref=$1 want=$2; shift 2
    $IP -4 rule show pref "$pref" | grep -qF "$want" && return 0
    while $IP -4 rule del pref "$pref" 2>/dev/null; do :; done
    $IP -4 rule add pref "$pref" "$@" && echo "rule $pref: $want"
}

clear_rules() {
    for p in 6089 6101 6102; do
        while $IP -4 rule del pref "$p" 2>/dev/null; do :; done
    done
}

[ "$1" = clear ] && { clear_rules; exit 0; }

# Return traffic and container<->host/LAN/hotspot use main (connected routes only).
ensure 6089 "from all to $POOL lookup main" to "$POOL" lookup main
ensure 6101 "from $POOL lookup main" from "$POOL" lookup main
# Internet: whatever table root's own traffic uses (normally wlan0).
UP=$($IP -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* table \([^ ]*\).*/\1/p')
[ -n "$UP" ] && ensure 6102 "from $POOL lookup $UP" from "$POOL" lookup "$UP"

# DNS for dockerd (static Go resolver reads /etc/resolv.conf, which Android lacks;
# nsroot.sh links it to this file): current network's servers + public fallbacks.
D=/data/docker
if [ -d "$D" ]; then
    NS=$(dumpsys connectivity 2>/dev/null | sed -n 's/.*DnsAddresses: \[\([^]]*\)\].*/\1/p' |
        tr ', ' '\n\n' | sed -n 's#^/##p' | grep -v '^fe80' | awk '!seen[$0]++' | head -2)
    NEW=$(for n in $NS 1.1.1.1 8.8.8.8; do echo "nameserver $n"; done | awk '!seen[$0]++' | head -3)
    [ "$NEW" = "$(cat "$D/resolv.conf" 2>/dev/null)" ] || echo "$NEW" > "$D/resolv.conf"
fi
exit 0
