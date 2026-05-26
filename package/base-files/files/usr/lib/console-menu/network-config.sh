#!/bin/sh

validate_ipv4() {
	local ip="$1"
	echo "$ip" | awk -F'.' '
		NF==4 {
			for(i=1;i<=4;i++) {
				if($i<0 || $i>255 || $i !~ /^[0-9]+$/) exit 1
			}
			exit 0
		}
		{exit 1}
	'
	return $?
}

validate_netmask() {
	local mask="$1"
	case "$mask" in
		[0-9])
			[ "$mask" -ge 0 ] 2>/dev/null && [ "$mask" -le 32 ] 2>/dev/null && return 0
			;;
		[1-9]|[12][0-9]|3[0-2])
			return 0
			;;
		*)
			validate_ipv4 "$mask" && return 0
			;;
	esac
	return 1
}

get_uci_section() {
	local iface="$1"
	uci show network 2>/dev/null | grep "\.device='$iface'" | head -1 | cut -d'.' -f2 | cut -d'=' -f1
}

ensure_uci_section() {
	local iface="$1"
	local section=$(get_uci_section "$iface")
	if [ -z "$section" ]; then
		section="${iface}_cfg"
		uci set "network.${section}=interface"
		uci set "network.${section}.device=$iface"
		uci commit network
	fi
	echo "$section"
}

load_current_config() {
	local section="$1"
	CONFIG_PROTO=$(uci -q get "network.${section}.proto" 2>/dev/null)
	CONFIG_IP=$(uci -q get "network.${section}.ipaddr" 2>/dev/null)
	CONFIG_MASK=$(uci -q get "network.${section}.netmask" 2>/dev/null)
	CONFIG_GATEWAY=$(uci -q get "network.${section}.gateway" 2>/dev/null)

	[ -z "$CONFIG_PROTO" ] && CONFIG_PROTO="static"
	[ -z "$CONFIG_IP" ] && CONFIG_IP="192.168.1.1"
	[ -z "$CONFIG_MASK" ] && CONFIG_MASK="255.255.255.0"
	[ -z "$CONFIG_GATEWAY" ] && CONFIG_GATEWAY=""
}

print_config_header() {
	local device="$1"
	local section="$2"
	local phys_iface="$3"
	local label=$(uci -q get "network.${section}.label" 2>/dev/null)
	[ -z "$label" ] && label="$section"
	cls
	print_separator
	if [ -n "$phys_iface" ] && [ "$phys_iface" != "$device" ]; then
		printf "=== Configure: %s -> %s (%s)\n\n" "$phys_iface" "$device" "$label"
	else
		printf "=== Configure: %s (%s)\n\n" "$device" "$label"
	fi
}

draw_config_menu() {
	printf "  Protocol:  %s\n\n" "$CONFIG_PROTO"

	printf "  [1] IP Address:     %s\n" "${CONFIG_IP:-<not set>}"
	printf "  [2] Netmask:        %s\n" "${CONFIG_MASK:-<not set>}"
	printf "  [3] Gateway:        %s\n" "${CONFIG_GATEWAY:-<not set>}"

	echo ""
	echo "  ---------------------------------------------------"
	printf "  [A] Apply & Save    [P] Change Protocol    [B] Back\n"
	echo ""
}

change_protocol() {
	cls
	echo ""
	echo "  Select protocol:"
	echo "  ---------------------------------------------------"
	echo "  [1] Static IP (manual configuration)"
	echo "  [2] DHCP (auto config)"
	echo "  [3] Unmanaged (no IP)"
	echo ""
	printf "  Choice > "
	read proto_choice < /dev/tty
	case "$proto_choice" in
		1) CONFIG_PROTO="static" ;;
		2) CONFIG_PROTO="dhcp" ;;
		3) CONFIG_PROTO="none" ;;
		*) printf "\n  Invalid choice. Press Enter..." ; read dummy < /dev/tty ;;
	esac
}

apply_config() {
	local iface="$1"
	local section=$(ensure_uci_section "$iface")

	uci set "network.${section}.proto=$CONFIG_PROTO"

	case "$CONFIG_PROTO" in
		static)
			uci set "network.${section}.ipaddr=$CONFIG_IP"
			uci set "network.${section}.netmask=$CONFIG_MASK"
			[ -n "$CONFIG_GATEWAY" ] && uci set "network.${section}.gateway=$CONFIG_GATEWAY"
			;;
	esac

	uci commit network

	echo ""
	echo "  Configuration saved. Reloading network..."
	/etc/init.d/network reload 2>/dev/null
	sleep 2
	echo "  Done."
	printf "  Press Enter to return..."
	read dummy < /dev/tty
}

config_interface() {
	local device="$1"
	local phys_iface="${2:-$device}"
	local section=$(ensure_uci_section "$device")

	load_current_config "$section"

	while true; do
		print_config_header "$device" "$section" "$phys_iface"
		draw_config_menu

		printf "  Select option > "
		read opt < /dev/tty

		case "$opt" in
			1)
				if [ "$CONFIG_PROTO" = "static" ]; then
					printf "\n  Enter new IP address: "
					read val < /dev/tty
					if [ -n "$val" ] && validate_ipv4 "$val"; then
						CONFIG_IP="$val"
						echo "  IP updated."
						sleep 1
					else
						printf "\n  Invalid IP address. Press Enter..."
						read dummy < /dev/tty
					fi
				else
					printf "\n  IP is managed by %s protocol. Press Enter..." "$CONFIG_PROTO"
					read dummy < /dev/tty
				fi
				;;
			2)
				if [ "$CONFIG_PROTO" = "static" ]; then
					printf "\n  Enter new netmask (e.g. 255.255.255.0 or 24): "
					read val < /dev/tty
					if [ -n "$val" ] && validate_netmask "$val"; then
						CONFIG_MASK="$val"
						echo "  Netmask updated."
						sleep 1
					else
						printf "\n  Invalid netmask. Press Enter..."
						read dummy < /dev/tty
					fi
				else
					printf "\n  Netmask is managed by %s protocol. Press Enter..." "$CONFIG_PROTO"
					read dummy < /dev/tty
				fi
				;;
			3)
				if [ "$CONFIG_PROTO" = "static" ]; then
					printf "\n  Enter new gateway IP: "
					read val < /dev/tty
					if [ -n "$val" ] && validate_ipv4 "$val"; then
						CONFIG_GATEWAY="$val"
						echo "  Gateway updated."
						sleep 1
					else
						printf "\n  Invalid gateway. Press Enter..."
						read dummy < /dev/tty
					fi
				else
					printf "\n  Gateway is managed by %s protocol. Press Enter..." "$CONFIG_PROTO"
					read dummy < /dev/tty
				fi
				;;
			[Aa])
				apply_config "$device"
				return
				;;
			[Pp])
				change_protocol
				;;
			[Bb])
				return
				;;
			*)
				printf "\n  Invalid choice. Press Enter..."
				read dummy < /dev/tty
				;;
		esac
	done
}
