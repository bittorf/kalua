#!/bin/sh

# e.g. user@hostname:~
export PS1='\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\] '

alias n='wget -qO - http://127.0.0.1:2006/neighbours'
alias n2='echo /nhdpinfo link | nc 127.0.0.1 2009'
alias ll='ls -la'
alias lr='logread'
alias flush='_system ram_free flush'
alias myssh='ssh -i $( _ssh key_public_fingerprint_get keyfilename )'
alias regen='/etc/kalua_init; _(){ false;}; . /tmp/loader'

case "$USER" in
	'root')
		grep -qs ^"root:\$1\$b6usD77Q\$XPs6VECsQzFy9TUuQUAHW1:" '/etc/shadow' && {
			echo "[ERROR] change weak root-password ('admin') with 'passwd'"
		}

		grep -qs ^'root:\$' '/etc/shadow' || {
			echo "[ERROR] set root-password with 'passwd'"
		}
	;;
esac

[ -e '/tmp/REBOOT_REASON' ] && {
	read -r CRASH <'/tmp/REBOOT_REASON'
	case "$CRASH" in
		'nocrash'|'nightly_reboot'|'apply_settings'|'wifimac_safed')
		;;
		*)
			# see system_crashreboot()
			echo "last reboot unusual = '$CRASH', see with: cat /sys/kernel/debug/crashlog"
		;;
	esac
	unset CRASH
}

_ t 2>/dev/null || {
	[ -e '/tmp/loader' ] && {
		. '/tmp/loader'
		echo
		echo 'for some hints type: _help overview'
	}
}
