#!/bin/sh

. /lib/functions.sh

SERVICE="smartdns-openclash-compat"
STATE_CONFIG="smartdns_openclash_compat"
STATE_SECTION="$STATE_CONFIG.state"
HOOK_FILE="/etc/openclash/custom/openclash_custom_overwrite.sh"
HOOK_BEGIN="# BEGIN SMARTDNS-OPENCLASH-COMPAT"
HOOK_END="# END SMARTDNS-OPENCLASH-COMPAT"
HOOK_COMMAND='[ -x /usr/libexec/smartdns-openclash-compat-overwrite ] && /usr/libexec/smartdns-openclash-compat-overwrite "${CONFIG_FILE:-$1}"'
LOCK_DIR="/var/lock/$SERVICE.lock"
STOP_FILE="/var/run/$SERVICE.stopping"
INTERVAL="5"
OPENCLASH_CHANGED="0"
SMARTDNS_SECTION=""
LOCK_HELD="0"

log_info() {
	logger -t "$SERVICE" "$*"
}

acquire_lock() {
	local retry="0" owner
	mkdir -p /var/lock
	while true; do
		if mkdir "$LOCK_DIR" 2>/dev/null; then
			echo "$$" > "$LOCK_DIR/owner"
			LOCK_HELD="1"
			return 0
		fi
		owner="$(cat "$LOCK_DIR/owner" 2>/dev/null)"
		if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
			rm -f "$LOCK_DIR/owner"
			rmdir "$LOCK_DIR" 2>/dev/null
			continue
		fi
		retry=$((retry + 1))
		if [ -z "$owner" ] && [ "$retry" -ge 2 ]; then
			rmdir "$LOCK_DIR" 2>/dev/null
			continue
		fi
		[ "$retry" -ge 20 ] && return 1
		sleep 1
	done
}

release_lock() {
	local owner
	[ "$LOCK_HELD" = "1" ] || return 0
	owner="$(cat "$LOCK_DIR/owner" 2>/dev/null)"
	[ "$owner" = "$$" ] || {
		LOCK_HELD="0"
		return 0
	}
	rm -f "$LOCK_DIR/owner"
	rmdir "$LOCK_DIR" 2>/dev/null
	LOCK_HELD="0"
}

find_smartdns_section_cb() {
	[ -z "$SMARTDNS_SECTION" ] && SMARTDNS_SECTION="$1"
}

find_smartdns_section() {
	SMARTDNS_SECTION=""
	config_load smartdns
	config_foreach find_smartdns_section_cb smartdns
	[ -n "$SMARTDNS_SECTION" ]
}

save_option() {
	local key="$1"
	local path="$2"
	local value

	if value="$(uci -q get "$path")"; then
		uci -q set "$STATE_SECTION.${key}_present=1"
		uci -q set "$STATE_SECTION.${key}_value=$value"
	else
		uci -q set "$STATE_SECTION.${key}_present=0"
		uci -q delete "$STATE_SECTION.${key}_value"
	fi
}

restore_option() {
	local key="$1"
	local path="$2"
	local present value

	present="$(uci -q get "$STATE_SECTION.${key}_present")"
	if [ "$present" = "1" ]; then
		value="$(uci -q get "$STATE_SECTION.${key}_value")"
		uci -q set "$path=$value"
	elif [ "$present" = "0" ]; then
		uci -q delete "$path"
	fi
}

dns_section_is_saved() {
	local target="$1"
	local item

	for item in $(uci -q get "$STATE_SECTION.dns_server_saved"); do
		[ "${item%%|*}" = "$target" ] && return 0
	done
	return 1
}

save_dns_section() {
	local section="$1"
	local present="0"
	local value=""

	dns_section_is_saved "$section" && return 0
	if value="$(uci -q get "openclash.$section.enabled")"; then
		present="1"
	fi
	uci -q add_list "$STATE_SECTION.dns_server_saved=$section|$present|$value"
}

save_dns_section_cb() {
	local section="$1"
	local group managed

	config_get group "$section" group
	config_get managed "$section" compat_managed "0"
	[ "$managed" = "1" ] && return 0
	case "$group" in
		nameserver|fallback) save_dns_section "$section" ;;
	esac
}

save_state() {
	find_smartdns_section || return 1

	uci -q delete "$STATE_SECTION"
	uci -q set "$STATE_SECTION=state"
	uci -q set "$STATE_SECTION.active=0"
	uci -q set "$STATE_SECTION.smartdns_section=$SMARTDNS_SECTION"
	save_option smartdns_auto_set_dnsmasq "smartdns.$SMARTDNS_SECTION.auto_set_dnsmasq"
	save_option openclash_enable_custom_dns "openclash.config.enable_custom_dns"
	save_option openclash_append_wan_dns "openclash.config.append_wan_dns"
	save_option openclash_append_default_dns "openclash.config.append_default_dns"
	uci -q commit "$STATE_CONFIG"

	config_load openclash
	config_foreach save_dns_section_cb dns_servers
	uci -q set "$STATE_SECTION.active=1"
	uci -q commit "$STATE_CONFIG"
	return 0
}

ensure_hook() {
	local hook_dir begin_line exit_line tmp_file

	hook_dir="${HOOK_FILE%/*}"
	mkdir -p "$hook_dir"
	if [ ! -f "$HOOK_FILE" ]; then
		printf '%s\n' '#!/bin/sh' > "$HOOK_FILE"
		chmod 0755 "$HOOK_FILE"
	fi
	begin_line="$(grep -n -F "$HOOK_BEGIN" "$HOOK_FILE" 2>/dev/null | head -n 1 | cut -d: -f1)"
	exit_line="$(awk '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ { line = NR } END { print line }' "$HOOK_FILE")"
	if [ -n "$begin_line" ] && { [ -z "$exit_line" ] || [ "$begin_line" -lt "$exit_line" ]; }; then
		return 0
	fi
	[ -n "$begin_line" ] && remove_hook

	tmp_file="$(mktemp "$HOOK_FILE.XXXXXX")" || return 1
	awk -v insert_at="$exit_line" -v begin="$HOOK_BEGIN" -v command="$HOOK_COMMAND" -v end="$HOOK_END" '
		NR == insert_at {
			print ""
			print begin
			print command
			print end
		}
		{ print }
		END {
			if (!insert_at) {
				print ""
				print begin
				print command
				print end
			}
		}
	' "$HOOK_FILE" > "$tmp_file" || {
		rm -f "$tmp_file"
		return 1
	}
	cat "$tmp_file" > "$HOOK_FILE"
	rm -f "$tmp_file"
	OPENCLASH_CHANGED="1"
}

remove_hook() {
	[ -f "$HOOK_FILE" ] || return 0
	grep -Fq "$HOOK_BEGIN" "$HOOK_FILE" 2>/dev/null || return 0
	sed -i "/^$HOOK_BEGIN$/,/^$HOOK_END$/d" "$HOOK_FILE"
}

ensure_dns_section_cb() {
	local section="$1"
	local group managed enabled

	config_get group "$section" group
	config_get managed "$section" compat_managed "0"
	[ "$managed" = "1" ] && return 0
	case "$group" in
		nameserver|fallback)
			save_dns_section "$section"
			config_get enabled "$section" enabled "1"
			if [ "$enabled" != "0" ]; then
				uci -q set "openclash.$section.enabled=0"
				OPENCLASH_CHANGED="1"
			fi
			;;
	esac
}

find_managed_dns_cb() {
	local section="$1"
	local managed

	config_get managed "$section" compat_managed "0"
	[ "$managed" = "1" ] || return 0
	if [ -z "$MANAGED_DNS_SECTION" ]; then
		MANAGED_DNS_SECTION="$section"
	else
		uci -q delete "openclash.$section"
		OPENCLASH_CHANGED="1"
	fi
}

set_if_changed() {
	local path="$1"
	local value="$2"
	[ "$(uci -q get "$path")" = "$value" ] && return 0
	uci -q set "$path=$value"
	OPENCLASH_CHANGED="1"
}

ensure_settings() {
	local smartdns_port

	find_smartdns_section || return 1
	smartdns_port="$(uci -q get "smartdns.$SMARTDNS_SECTION.port")"
	[ -n "$smartdns_port" ] || smartdns_port="6053"

	OPENCLASH_CHANGED="0"
	ensure_hook
	set_if_changed openclash.config.enable_custom_dns 1
	set_if_changed openclash.config.append_wan_dns 0
	set_if_changed openclash.config.append_default_dns 0
	[ "$(uci -q get "smartdns.$SMARTDNS_SECTION.auto_set_dnsmasq")" = "0" ] || \
		uci -q set "smartdns.$SMARTDNS_SECTION.auto_set_dnsmasq=0"

	config_load openclash
	config_foreach ensure_dns_section_cb dns_servers

	MANAGED_DNS_SECTION=""
	config_load openclash
	config_foreach find_managed_dns_cb dns_servers
	if [ -z "$MANAGED_DNS_SECTION" ]; then
		MANAGED_DNS_SECTION="$(uci -q add openclash dns_servers)"
		uci -q set "openclash.$MANAGED_DNS_SECTION.compat_managed=1"
		OPENCLASH_CHANGED="1"
	fi
	set_if_changed "openclash.$MANAGED_DNS_SECTION.group" nameserver
	set_if_changed "openclash.$MANAGED_DNS_SECTION.type" udp
	set_if_changed "openclash.$MANAGED_DNS_SECTION.ip" 127.0.0.1
	set_if_changed "openclash.$MANAGED_DNS_SECTION.port" "$smartdns_port"
	set_if_changed "openclash.$MANAGED_DNS_SECTION.enabled" 1

	uci -q commit smartdns
	uci -q commit openclash
	uci -q commit "$STATE_CONFIG"
	return 0
}

remove_managed_dns_cb() {
	local section="$1"
	local managed

	config_get managed "$section" compat_managed "0"
	[ "$managed" = "1" ] && uci -q delete "openclash.$section"
}

restore_dns_item() {
	local item="$1"
	local section rest present value

	section="${item%%|*}"
	rest="${item#*|}"
	present="${rest%%|*}"
	value="${rest#*|}"
	uci -q get "openclash.$section" >/dev/null || return 0
	if [ "$present" = "1" ]; then
		uci -q set "openclash.$section.enabled=$value"
	else
		uci -q delete "openclash.$section.enabled"
	fi
}

restore_locked() {
	local restart_services="${1:-1}"
	local smartdns_section original_auto openclash_running="0" smartdns_running="0"
	local item

	[ "$(uci -q get "$STATE_SECTION.active")" = "1" ] || {
		remove_hook
		return 0
	}

	/etc/init.d/openclash running >/dev/null 2>&1 && openclash_running="1"
	/etc/init.d/smartdns running >/dev/null 2>&1 && smartdns_running="1"
	smartdns_section="$(uci -q get "$STATE_SECTION.smartdns_section")"
	original_auto="$(uci -q get "$STATE_SECTION.smartdns_auto_set_dnsmasq_value")"

	remove_hook
	config_load openclash
	config_foreach remove_managed_dns_cb dns_servers
	for item in $(uci -q get "$STATE_SECTION.dns_server_saved"); do
		restore_dns_item "$item"
	done
	restore_option openclash_enable_custom_dns openclash.config.enable_custom_dns
	restore_option openclash_append_wan_dns openclash.config.append_wan_dns
	restore_option openclash_append_default_dns openclash.config.append_default_dns
	[ -n "$smartdns_section" ] && restore_option smartdns_auto_set_dnsmasq "smartdns.$smartdns_section.auto_set_dnsmasq"
	uci -q commit openclash
	uci -q commit smartdns

	uci -q delete "$STATE_SECTION"
	uci -q set "$STATE_SECTION=state"
	uci -q set "$STATE_SECTION.active=0"
	uci -q commit "$STATE_CONFIG"
	log_info "已恢复 SmartDNS 与 OpenClash 的原始 DNS 配置"

	[ "$restart_services" = "1" ] || return 0
	if [ "$openclash_running" = "1" ] && [ "$(uci -q get openclash.config.enable)" = "1" ]; then
		/etc/init.d/openclash restart >/dev/null 2>&1
	fi
	if [ "$smartdns_running" = "1" ] && [ "$original_auto" = "1" ]; then
		/etc/init.d/smartdns restart >/dev/null 2>&1
	fi
}

compatibility_required() {
	[ "$(uci -q get openclash.config.enable)" = "1" ] || return 1
	find_smartdns_section || return 1
	[ "$(uci -q get "smartdns.$SMARTDNS_SECTION.enabled")" = "1" ]
}

reconcile_locked() {
	local was_active restart_openclash="0"

	[ -e "$STOP_FILE" ] && return 0
	was_active="$(uci -q get "$STATE_SECTION.active")"
	if ! compatibility_required; then
		[ "$was_active" = "1" ] && restore_locked 1
		return 0
	fi

	if [ "$was_active" != "1" ]; then
		save_state || {
			log_info "无法保存原始配置，已跳过兼容处理"
			return 1
		}
		log_info "检测到 OpenClash 与 SmartDNS 已启用，开始接管 DNS 兼容配置"
	fi

	ensure_settings || return 1
	[ "$OPENCLASH_CHANGED" = "1" ] && /etc/init.d/openclash running >/dev/null 2>&1 && restart_openclash="1"
	if [ "$restart_openclash" = "1" ]; then
		/etc/init.d/openclash restart >/dev/null 2>&1
	fi
}

reconcile() {
	local result
	acquire_lock || return 1
	reconcile_locked
	result="$?"
	release_lock
	return "$result"
}

restore() {
	local result
	acquire_lock || return 1
	restore_locked "${1:-1}"
	result="$?"
	release_lock
	return "$result"
}

run() {
	trap 'release_lock; exit 0' TERM INT
	while true; do
		reconcile
		sleep "$INTERVAL" &
		wait $!
	done
}

case "$1" in
	run) run ;;
	reconcile) reconcile ;;
	restore) restore "$2" ;;
	*)
		echo "用法: $0 {run|reconcile|restore [0|1]}" >&2
		exit 1
		;;
esac
