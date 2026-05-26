#!/bin/sh

CM_DIR="/usr/lib/console-menu"

cls() {
	printf '\033[2J\033[H'
}

print_separator() {
	echo "======================================================"
}

draw_header() {
	cls
	print_separator
	if [ -f /etc/banner ]; then
		cat /etc/banner
	else
		echo "  OpenWrt"
	fi
	print_separator
}

draw_version() {
	if [ -f /etc/openwrt_release ]; then
		printf "  Version: "
		local dist=$(grep 'DISTRIB_DESCRIPTION' /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
		local rev=$(grep 'DISTRIB_REVISION' /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
		if [ -n "$dist" ]; then
			printf "%s" "$dist"
			[ -n "$rev" ] && printf " | %s" "$rev"
		elif [ -n "$rev" ]; then
			printf "OpenWrt | %s" "$rev"
		else
			printf "OpenWrt"
		fi
		echo ""
	else
		echo "  Version: OpenWrt"
	fi
}

get_iface_speed() {
	local iface="$1"
	local speed=""
	if [ -f "/sys/class/net/${iface}/speed" ]; then
		read speed < "/sys/class/net/${iface}/speed" 2>/dev/null
		echo "${speed}Mbps"
	else
		echo "-"
	fi
}

get_iface_state() {
	local iface="$1"
	if [ -f "/sys/class/net/${iface}/carrier" ]; then
		local carrier
		read carrier < "/sys/class/net/${iface}/carrier" 2>/dev/null
		[ "$carrier" = "1" ] && echo "UP" && return
	fi
	if [ -f "/sys/class/net/${iface}/operstate" ]; then
		local state
		read state < "/sys/class/net/${iface}/operstate" 2>/dev/null
		[ "$state" = "up" ] && echo "UP" && return
	fi
	echo "DOWN"
}

get_iface_ip() {
	local iface="$1"
	ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1
}

get_iface_uci_section() {
	local iface="$1"
	uci show network 2>/dev/null | grep "\.device='$iface'" | head -1 | cut -d'.' -f2 | cut -d'=' -f1
}

get_iface_proto() {
	local section="$1"
	if [ -n "$section" ]; then
		uci -q get "network.${section}.proto" 2>/dev/null
	else
		echo ""
	fi
}

get_iface_uci_label() {
	local section="$1"
	if [ -n "$section" ]; then
		local label=$(uci -q get "network.${section}.label" 2>/dev/null)
		if [ -z "$label" ]; then
			echo "$section"
		else
			echo "$label"
		fi
	else
		echo "unconfigured"
	fi
}

get_bridge_master() {
	local iface="$1"
	if [ -L "/sys/class/net/${iface}/master" ]; then
		basename "$(readlink "/sys/class/net/${iface}/master" 2>/dev/null)" 2>/dev/null
		return
	fi
	echo ""
}

is_bridge_slave() {
	local iface="$1"
	[ -d "/sys/class/net/${iface}/brport" ] || [ -L "/sys/class/net/${iface}/master" ]
}

scan_eth_interfaces() {
	for d in /sys/class/net/eth* /sys/class/net/en*; do
		[ -d "$d" ] || continue
		local name=$(basename "$d")
		echo "$name"
	done
}

draw_network_list() {
	echo ""
	echo "  Network Interfaces:"
	echo " ---------------------------------------------------"

	local idx=1
	INTERFACES=""
	for iface in $(scan_eth_interfaces); do
		local state=$(get_iface_state "$iface")
		local speed=$(get_iface_speed "$iface")
		local config_device="$iface"
		local display_name="$iface"

		if is_bridge_slave "$iface"; then
			local bridge=$(get_bridge_master "$iface")
			if [ -n "$bridge" ]; then
				config_device="$bridge"
				display_name="${iface}->${bridge}"
			fi
		fi

		local ipaddr=$(get_iface_ip "$config_device")
		local section=$(get_iface_uci_section "$config_device")
		local proto=$(get_iface_proto "$section")
		local label=$(get_iface_uci_label "$section")

		[ -z "$ipaddr" ] && ipaddr="-"
		[ -z "$proto" ] && proto="unset"
		if [ "$state" = "DOWN" ]; then
			speed="-"
		fi

		printf "  [%d]  %-12s %-4s %-10s %-18s (%s / %s)\n" \
			"$idx" "$display_name" "$state" "$speed" "$ipaddr" "$label" "$proto"

		INTERFACES="${INTERFACES}${config_device}:${iface}
"
		idx=$((idx + 1))
	done

	if [ -z "$INTERFACES" ]; then
		echo "  [No physical Ethernet interfaces detected]"
	fi
}

draw_footer() {
	local count=$(printf '%s' "$INTERFACES" | grep -c '^' 2>/dev/null)
	if [ "$count" -gt 0 ]; then
		echo ""
		echo " ---------------------------------------------------"
		printf "  [1-%d] Configure interface   [R] Refresh   [Q] Exit\n" "$count"
	else
		echo ""
		echo " ---------------------------------------------------"
		echo "  [R] Refresh   [Q] Exit"
	fi
	echo ""
}

main_menu_loop() {
	draw_header
	draw_version
	draw_network_list
	draw_footer

	while true; do
		printf "  Enter choice > "
		read choice

		case "$choice" in
			[Rr])
				draw_header
				draw_version
				draw_network_list
				draw_footer
				;;
			[Qq])
				break
				;;
			*)
				handle_numeric_choice "$choice"
				draw_header
				draw_version
				draw_network_list
				draw_footer
				;;
		esac
	done
}

handle_numeric_choice() {
	local choice="$1"
	local chosen_device=""
	local chosen_eth=""

	local line_data=$(printf '%s\n' "$INTERFACES" | sed -n "${choice}p" 2>/dev/null)
	chosen_device=$(echo "$line_data" | cut -d':' -f1)
	chosen_eth=$(echo "$line_data" | cut -d':' -f2)

	if [ -n "$chosen_device" ]; then
		if [ -f "$CM_DIR/network-config.sh" ]; then
			. "$CM_DIR/network-config.sh"
			config_interface "$chosen_device" "$chosen_eth"
		fi
	else
		echo ""
		printf "  Invalid choice. Press Enter to continue..."
		read dummy
	fi
}
