#!/bin/sh

set -eu

blocklist="/etc/banip/banip.blocklist"
backup="/tmp/banip.blocklist.before-authority-test"
provider="/etc/openclash/rule_provider/banip-authority.yaml"

last_run_marker() {
	/etc/init.d/banip status 2>/dev/null | sed -n 's/^  + last_run *: //p'
}

wait_for_banip() {
	local previous="$1"
	local elapsed="0" marker status
	while [ "$elapsed" -lt 180 ]; do
		status="$(/etc/init.d/banip status 2>/dev/null)"
		marker="$(printf '%s\n' "$status" | sed -n 's/^  + last_run *: //p')"
		if printf '%s\n' "$status" | grep -q 'status *: active' && \
			[ -n "$marker" ] && [ "$marker" != "$previous" ]; then
			return 0
		fi
		sleep 5
		elapsed=$((elapsed + 5))
	done
	echo '等待 banIP 重新加载超时' >&2
	return 1
}

wait_for_provider() {
	local expected="$1"
	local elapsed="0" matches="0"
	[ -x /etc/init.d/openclash ] || return 0
	while [ "$elapsed" -lt 90 ]; do
		matches="0"
		[ -f "$provider" ] && grep -Fq 'DOMAIN-SUFFIX,example.org' "$provider" && matches=$((matches + 1))
		[ -f "$provider" ] && grep -Fq 'IP-CIDR,203.0.113.55/32' "$provider" && matches=$((matches + 1))
		[ "$expected" = "present" ] && [ "$matches" -eq 2 ] && return 0
		[ "$expected" = "absent" ] && [ "$matches" -eq 0 ] && return 0
		sleep 3
		elapsed=$((elapsed + 3))
	done
	echo '等待 OpenClash banIP 规则提供者更新超时' >&2
	return 1
}

case "${1:-}" in
	apply)
		previous="$(last_run_marker)"
		[ -f "$backup" ] || cp "$blocklist" "$backup"
		grep -Fqx '203.0.113.55' "$blocklist" || printf '%s\n' '203.0.113.55' >> "$blocklist"
		grep -Fqx 'example.org' "$blocklist" || printf '%s\n' 'example.org' >> "$blocklist"
		/etc/init.d/banip reload
		wait_for_banip "$previous"
		wait_for_provider present
		;;
	restore)
		[ -f "$backup" ] || {
			echo '找不到测试前的 banIP 封禁列表备份' >&2
			exit 1
		}
		previous="$(last_run_marker)"
		cp "$backup" "$blocklist"
		/etc/init.d/banip reload
		wait_for_banip "$previous"
		wait_for_provider absent
		rm -f "$backup"
		;;
	*)
		echo "用法: $0 {apply|restore}" >&2
		exit 1
		;;
esac
