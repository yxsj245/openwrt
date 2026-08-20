#!/bin/sh

set -eu

wan_device="${1:-eth0}"
lan_device="${2:-eth1}"
wan_address="${3:-192.168.123.3}"
wan_gateway="${4:-192.168.123.1}"
lan_address="${5:-10.77.0.1}"
enable_qosmate="${6:-}"

ip link show "$wan_device" >/dev/null
ip link show "$lan_device" >/dev/null

uci -q set network.@device[0].ports="$lan_device"
uci -q set network.lan.device='br-lan'
uci -q set network.lan.proto='static'
uci -q set network.lan.ipaddr="$lan_address"
uci -q set network.lan.netmask='255.255.255.0'
uci -q delete network.lan.gateway || true
uci -q delete network.lan.dns || true

uci -q delete network.wan || true
uci -q set network.wan='interface'
uci -q set network.wan.device="$wan_device"
uci -q set network.wan.proto='static'
uci -q set network.wan.ipaddr="$wan_address"
uci -q set network.wan.netmask='255.255.255.0'
uci -q set network.wan.gateway="$wan_gateway"
uci -q add_list network.wan.dns="$wan_gateway"

uci -q set dhcp.lan.ignore='0'
uci -q set dhcp.lan.start='100'
uci -q set dhcp.lan.limit='100'
uci -q set dhcp.lan.leasetime='12h'

rule="$(
	uci -q show firewall | sed -n "s/^firewall\.\([^.=]*\)=rule$/\1/p" | while read -r section; do
	[ "$(uci -q get firewall.$section.name)" = "Allow-Test-Management" ] && {
		printf '%s' "$section"
		break
	}
	done || true
)"
[ -n "$rule" ] || rule="$(uci -q add firewall rule)"
uci -q set firewall."$rule".name='Allow-Test-Management'
uci -q set firewall."$rule".src='wan'
uci -q set firewall."$rule".src_ip='192.168.123.0/24'
uci -q set firewall."$rule".proto='tcp'
uci -q set firewall."$rule".dest_port='22 80 443'
uci -q set firewall."$rule".target='ACCEPT'

uci -q set banip.global.ban_enabled='1'
uci -q set banip.global.ban_trigger='wan'
uci -q set banip.global.ban_autoallowlist='1'
uci -q set banip.global.ban_autoallowuplink='subnet'
uci -q set banip.global.ban_allowlistonly='0'

if uci -q get qosmate.settings.WAN >/dev/null 2>&1; then
	uci -q set qosmate.settings.WAN='auto'
	[ "$enable_qosmate" = "1" ] && uci -q set qosmate.global.enabled='1'
	uci -q commit qosmate
fi

uci -q commit network
uci -q commit dhcp
uci -q commit firewall
uci -q commit banip

/etc/init.d/banip enable
[ -x /etc/init.d/banip-authority ] && /etc/init.d/banip-authority enable
/etc/init.d/network reload
sleep 3
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart
/etc/init.d/banip restart
[ -x /etc/init.d/banip-authority ] && /etc/init.d/banip-authority restart
if [ "$(uci -q get qosmate.global.enabled)" = "1" ]; then
	/etc/init.d/qosmate restart
fi
