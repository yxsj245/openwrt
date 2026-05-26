#!/bin/sh
[ -t 0 ] || return 0

tty_dev=$(readlink /proc/self/fd/0 2>/dev/null)
case "$tty_dev" in
	/dev/console|/dev/tty[0-9]*|/dev/ttyS[0-9]*|/dev/ttyAMA[0-9]*|/dev/hvc[0-9]*)
		;;
	*)
		return 0
		;;
esac

if [ -f /usr/lib/console-menu/display.sh ]; then
	. /usr/lib/console-menu/display.sh
	main_menu_loop
	cls
fi
