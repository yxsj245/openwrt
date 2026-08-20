#!/bin/sh

STATE="smartdns_openclash_compat.state"

[ "$(uci -q get "$STATE.active")" = "1" ] || exit 0
[ -n "$1" ] && [ -f "$1" ] || exit 0
[ -r /usr/share/openclash/ruby.sh ] || exit 0

. /usr/share/openclash/ruby.sh

# 订阅文件可能自带 fallback，必须在 OpenClash 完成自身覆写后删除。
ruby_delete "$1" "['dns']" "fallback"
