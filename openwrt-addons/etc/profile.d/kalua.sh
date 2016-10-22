#!/bin/sh

prompt_set()
{
	face()
	{
		local rc=$?

		case "$rc" in
			0) printf '%s' "$1" ;;
			*) printf '%s' "$2" ; return $rc ;;
		esac
	}

	local e='\[\e'			# start escape-sequence
	local c='\]'			# close escape-sequence

	local user='\u'
	local wdir='\w'			# workdir
	local host='\h'			# short form

	local reset="${e}[0m${c}"	# all attributes
	local white="${e}[37m${c}"
	local cyan="${e}[36m${c}"
	local yellow="${e}[33;1m${c}"	# bold
	local green="${e}[32m${c}"
	local red="${e}[31m${c}"

	local ok="${green}:)"
	local bad="${red}8("

	# e.g. user@hostname:~ :)
	export PS1="${cyan}${user}$white@${green}$host:${yellow}$wdir \$( face '$ok' '$bad' ) $reset"
}

prompt_set

alias n='_olsr txtinfo'
alias n2='echo /nhdpinfo link | nc 127.0.0.1 2009'
alias ll='ls -la'
alias lr='logread'
alias flush='_system ram_free flush'
alias myssh='ssh -i $( _ssh key_public_fingerprint_get keyfilename )'
alias regen='_ rebuild; _(){ false;}; . /tmp/loader'
alias unload='_ u'
alias dropshell='echo >>$SCHEDULER_IMPORTANT "/etc/init.d/dropbear stop"; killall dropbear'

read -r LOAD <'/proc/loadavg'
case "$LOAD" in
	'0'*)
	;;
	*)
		echo '[ATT] high load:'
		uptime
	;;
esac
unset LOAD

read -r UP REST <'/proc/uptime'
UP="${UP%.*}"
case "${#UP}" in 1|2|3) echo "[ATT] low uptime: $UP sec";; esac
unset UP REST

case "$USER" in
	'root'|'')
		# FIXME! needs 'mkpasswd'
		grep -qs ^"root:\$1\$b6usD77Q\$XPs6VECsQzFy9TUuQUAHW1:" '/etc/shadow' && {
			echo "[ERROR] change weak password ('admin') with 'passwd'"
		}

		grep -qs ^'root:\$' '/etc/shadow' || {
			echo "[ERROR] unset password, use 'passwd'"
		}
	;;
esac

_ t 2>/dev/null || {
	[ -e '/tmp/loader' -a -n "$SSH_CONNECTION" ] && {
		# http://unix.stackexchange.com/questions/82347/how-to-check-if-a-user-can-access-a-given-file
		. '/tmp/loader'		# TODO: avoid "no permission" on debian user-X-session

		echo
		echo "this is a '$HARDWARE' - for some hints type: _help overview"

		NAME="$( _wifi longshot_name )" && {
			echo
			echo "this device is part of a wifi-longshot named '$NAME'"
			echo 'get stats with: _wifi longshot_report'
		}

		unload wifi
		unset NAME
	}
}

if   [ -e '/etc/init.d/apply_profile' -a -e '/sbin/uci' ]; then
	echo "fresh/unconfigured device detected, run: '/etc/init.d/apply_profile.code' for help"
elif [ -e '/tmp/REBOOT_REASON' ]; then
	# see system_crashreboot()
	read -r CRASH <'/tmp/REBOOT_REASON'
	_system include

	case "$CRASH" in
		'nocrash'|'nightly_reboot'|'apply_profile'|'wifimac_safed')
			CRASH="$( _system reboots )"

			test ${CRASH:-0} -gt 50 && {
				echo "detected $CRASH reboots since last update - please check"
			}
		;;
		*)
			UNIXTIME=$( date +%s )
			UPTIME=$( _system uptime sec )
			printf '\n%s' "last reboot unusual @ $( date -d @$(( UNIXTIME - UPTIME )) ) - "

			if [ -e '/sys/kernel/debug/crashlog' ]; then
				printf '%s\n\n' "was: $CRASH, see with: cat /sys/kernel/debug/crashlog"
			else
				printf '%s\n\n' "was: $CRASH"
			fi
		;;
	esac

	unset CRASH UNIXTIME UPTIME
	unload system
fi
