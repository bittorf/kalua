#!/bin/sh

# e.g. user@hostname:~
export PS1='\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\] '

alias n='_olsr txtinfo'
alias n2='echo /nhdpinfo link | nc 127.0.0.1 2009'
alias ll='ls -la'
alias lr='logread'
alias flush='_system ram_free flush'
alias myssh='ssh -i $( _ssh key_public_fingerprint_get keyfilename )'
alias regen='_ rebuild; _(){ false;}; . /tmp/loader'

case "$USER" in
	'root'|'')
		grep -qs ^"root:\$1\$b6usD77Q\$XPs6VECsQzFy9TUuQUAHW1:" '/etc/shadow' && {
			echo "[ERROR] change weak password ('admin') with 'passwd'"
		}

		grep -qs ^'root:\$' '/etc/shadow' || {
			echo "[ERROR] unset password, use 'passwd'"
		}
	;;
esac

_ t 2>/dev/null || {
	[ -e '/tmp/loader' ] && {
		. '/tmp/loader'
		echo
		echo 'for some hints type: _help overview'
	}
}

if   [ -e '/etc/init.d/apply_profile' -a -e '/sbin/uci' ]; then
	echo "fresh/unconfigured device detected, run: '/etc/init.d/apply_profile.code' for help"
elif [ -e '/tmp/REBOOT_REASON' ]; then
	# see system_crashreboot()
	read -r CRASH <'/tmp/REBOOT_REASON'
	case "$CRASH" in
		'nocrash'|'nightly_reboot'|'apply_profile'|'wifimac_safed')
			CRASH="$( _system reboots )"
			test ${CRASH:-0} -gt 50 && {
				echo "detected $CRASH reboots since last update - please check"
			}
		;;
		*)
			if [ -e '/sys/kernel/debug/crashlog' ]; then
				echo "last reboot unusual = '$CRASH', see with: cat /sys/kernel/debug/crashlog"
			else
				echo "last reboot unusual = '$CRASH'"
			fi
		;;
	esac
	unset CRASH
fi
