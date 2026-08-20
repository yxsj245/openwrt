#!/bin/sh

. /lib/functions.sh

SERVICE="banip-authority"
CONFIG="banip_authority"
STATE="$CONFIG.state"
HOOK_FILE="/etc/openclash/custom/openclash_custom_overwrite.sh"
HOOK_BEGIN="# BEGIN BANIP-AUTHORITY"
HOOK_END="# END BANIP-AUTHORITY"
HOOK_COMMAND='[ -x /usr/libexec/banip-authority-openclash-overwrite ] && /usr/libexec/banip-authority-openclash-overwrite "${CONFIG_FILE:-$1}"'
PROVIDER_FILE="/etc/openclash/rule_provider/banip-authority.yaml"
BLOCKLIST="/etc/banip/banip.blocklist"
NFT_CHAIN_PREROUTING="authority-prerouting"
NFT_CHAIN_OUTPUT="authority-output"
PROVIDER_TICKS="0"

log_info() {
	logger -t "$SERVICE" "$*"
}

valid_interval() {
	case "$1" in
		''|*[!0-9]*) return 1 ;;
	esac
	[ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

get_priority() {
	local priority
	priority="$(uci -q get "$CONFIG.main.nft_priority")"
	case "$priority" in
		-[0-9]*) ;;
		*) priority="-300" ;;
	esac
	[ "$priority" -le -176 ] 2>/dev/null || priority="-300"
	[ "$priority" -ge -1000 ] 2>/dev/null || priority="-300"
	printf '%s' "$priority"
}

find_smartdns_section_cb() {
	[ -z "$SMARTDNS_SECTION" ] && SMARTDNS_SECTION="$1"
}

smartdns_resolver() {
	local port
	SMARTDNS_SECTION=""
	config_load smartdns
	config_foreach find_smartdns_section_cb smartdns
	[ -n "$SMARTDNS_SECTION" ] || return 1
	config_get port "$SMARTDNS_SECTION" port "6053"
	case "$port" in
		''|*[!0-9]*) return 1 ;;
	esac
	printf '127.0.0.1:%s' "$port"
}

save_resolver_state() {
	local resolver
	[ "$(uci -q get "$STATE.resolver_saved")" = "1" ] && return 0
	if resolver="$(uci -q get banip.global.ban_resolver)"; then
		uci -q set "$STATE.resolver_present=1"
		uci -q set "$STATE.resolver_value=$resolver"
	else
		uci -q set "$STATE.resolver_present=0"
		uci -q delete "$STATE.resolver_value"
	fi
	uci -q set "$STATE.resolver_saved=1"
	uci -q commit "$CONFIG"
}

ensure_resolver() {
	local resolver current
	[ "$(uci -q get "$CONFIG.main.manage_resolver")" = "1" ] || return 0
	resolver="$(smartdns_resolver)" || return 0
	current="$(uci -q get banip.global.ban_resolver)"
	[ "$current" = "$resolver" ] && return 0
	save_resolver_state
	uci -q set banip.global.ban_resolver="$resolver"
	uci -q commit banip
	log_info "banIP 域名解析器已切换到 SmartDNS：$resolver"
}

restore_resolver() {
	local present value
	[ "$(uci -q get "$STATE.resolver_saved")" = "1" ] || return 0
	present="$(uci -q get "$STATE.resolver_present")"
	if [ "$present" = "1" ]; then
		value="$(uci -q get "$STATE.resolver_value")"
		uci -q set banip.global.ban_resolver="$value"
	else
		uci -q delete banip.global.ban_resolver
	fi
	uci -q commit banip
	uci -q delete "$STATE.resolver_saved"
	uci -q delete "$STATE.resolver_present"
	uci -q delete "$STATE.resolver_value"
	uci -q commit "$CONFIG"
}

ensure_nft_chains() {
	local priority
	nft list chain inet banIP _inbound >/dev/null 2>&1 || return 1
	nft list chain inet banIP _outbound >/dev/null 2>&1 || return 1
	if nft list chain inet banIP "$NFT_CHAIN_PREROUTING" >/dev/null 2>&1 && \
		nft list chain inet banIP "$NFT_CHAIN_OUTPUT" >/dev/null 2>&1; then
		return 0
	fi

	remove_nft_chains
	priority="$(get_priority)"
	{
		printf 'add chain inet banIP %s { type filter hook prerouting priority %s; policy accept; }\n' "$NFT_CHAIN_PREROUTING" "$priority"
		printf 'add rule inet banIP %s jump _inbound\n' "$NFT_CHAIN_PREROUTING"
		printf 'add rule inet banIP %s ip daddr 198.18.0.0/15 return\n' "$NFT_CHAIN_PREROUTING"
		printf 'add rule inet banIP %s jump _outbound\n' "$NFT_CHAIN_PREROUTING"
		printf 'add chain inet banIP %s { type filter hook output priority %s; policy accept; }\n' "$NFT_CHAIN_OUTPUT" "$priority"
		printf 'add rule inet banIP %s ip daddr 198.18.0.0/15 return\n' "$NFT_CHAIN_OUTPUT"
		printf 'add rule inet banIP %s jump _outbound\n' "$NFT_CHAIN_OUTPUT"
	} | nft -f - || return 1
	PROVIDER_TICKS="999999"
	log_info "已在优先级 $priority 安装 banIP 强制封禁链"
}

remove_nft_chains() {
	nft delete chain inet banIP "$NFT_CHAIN_PREROUTING" >/dev/null 2>&1
	nft delete chain inet banIP "$NFT_CHAIN_OUTPUT" >/dev/null 2>&1
}

ensure_hook() {
	local begin_line exit_line tmp_file
	mkdir -p "${HOOK_FILE%/*}"
	if [ ! -f "$HOOK_FILE" ]; then
		printf '%s\n' '#!/bin/sh' > "$HOOK_FILE"
		chmod 0755 "$HOOK_FILE"
	fi
	begin_line="$(grep -n -F "$HOOK_BEGIN" "$HOOK_FILE" 2>/dev/null | head -n 1 | cut -d: -f1)"
	exit_line="$(awk '/^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ { line = NR } END { print line }' "$HOOK_FILE")"
	if [ -n "$begin_line" ] && { [ -z "$exit_line" ] || [ "$begin_line" -lt "$exit_line" ]; }; then
		return 1
	fi
	[ -n "$begin_line" ] && remove_hook

	tmp_file="$(mktemp "$HOOK_FILE.XXXXXX")" || return 1
	awk -v insert_at="$exit_line" -v begin="$HOOK_BEGIN" -v command="$HOOK_COMMAND" -v end="$HOOK_END" '
		NR == insert_at { print ""; print begin; print command; print end }
		{ print }
		END { if (!insert_at) { print ""; print begin; print command; print end } }
	' "$HOOK_FILE" > "$tmp_file" || {
		rm -f "$tmp_file"
		return 1
	}
	cat "$tmp_file" > "$HOOK_FILE"
	rm -f "$tmp_file"
	return 0
}

remove_hook() {
	[ -f "$HOOK_FILE" ] || return 0
	grep -Fq "$HOOK_BEGIN" "$HOOK_FILE" 2>/dev/null || return 0
	sed -i "/^$HOOK_BEGIN$/,/^$HOOK_END$/d" "$HOOK_FILE"
}

generate_provider() {
	local tmp_file changed="0"
	mkdir -p "${PROVIDER_FILE%/*}"
	tmp_file="$(mktemp "$PROVIDER_FILE.XXXXXX")" || return 1
	if ! nft -j list table inet banIP 2>/dev/null | \
		/usr/libexec/banip-authority-provider "$BLOCKLIST" > "$tmp_file"; then
		rm -f "$tmp_file"
		return 1
	fi
	if [ ! -f "$PROVIDER_FILE" ] || ! cmp -s "$tmp_file" "$PROVIDER_FILE"; then
		mv "$tmp_file" "$PROVIDER_FILE"
		changed="1"
	else
		rm -f "$tmp_file"
	fi
	if ensure_hook; then
		changed="1"
	fi
	[ "$changed" = "1" ] || return 0
	log_info "OpenClash 最高优先级封禁规则已更新"
	if [ "$(uci -q get openclash.config.enable)" = "1" ] && /etc/init.d/openclash running >/dev/null 2>&1; then
		/etc/init.d/openclash restart >/dev/null 2>&1 &
	fi
}

remove_openclash_policy() {
	local changed="0"
	grep -Fq "$HOOK_BEGIN" "$HOOK_FILE" 2>/dev/null && changed="1"
	[ -f "$PROVIDER_FILE" ] && changed="1"
	remove_hook
	rm -f "$PROVIDER_FILE"
	if [ "$changed" = "1" ] && [ "$(uci -q get openclash.config.enable)" = "1" ] && \
		/etc/init.d/openclash running >/dev/null 2>&1; then
		/etc/init.d/openclash restart >/dev/null 2>&1 &
	fi
}

reconcile() {
	local provider_interval
	[ "$(uci -q get "$CONFIG.main.enabled")" = "1" ] || {
		restore
		return 0
	}
	[ "$(uci -q get banip.global.ban_enabled)" = "1" ] || {
		remove_nft_chains
		remove_openclash_policy
		return 0
	}

	ensure_resolver
	ensure_nft_chains || return 0
	uci -q set "$STATE.active=1"
	uci -q commit "$CONFIG"

	provider_interval="$(uci -q get "$CONFIG.main.provider_interval")"
	valid_interval "$provider_interval" 5 3600 || provider_interval="15"
	PROVIDER_TICKS=$((PROVIDER_TICKS + CHECK_INTERVAL))
	if [ "$PROVIDER_TICKS" -ge "$provider_interval" ]; then
		PROVIDER_TICKS="0"
		generate_provider
	fi
}

restore() {
	remove_nft_chains
	remove_openclash_policy
	restore_resolver
	uci -q set "$STATE.active=0"
	uci -q commit "$CONFIG"
}

run() {
	CHECK_INTERVAL="$(uci -q get "$CONFIG.main.check_interval")"
	valid_interval "$CHECK_INTERVAL" 1 60 || CHECK_INTERVAL="2"
	trap 'exit 0' TERM INT
	while true; do
		reconcile
		sleep "$CHECK_INTERVAL" &
		wait $!
	done
}

case "$1" in
	run) run ;;
	reconcile) CHECK_INTERVAL="2"; reconcile ;;
	restore) restore ;;
	*)
		echo "用法: $0 {run|reconcile|restore}" >&2
		exit 1
		;;
esac
