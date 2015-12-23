#!/bin/sh

network="$1"	# e.g. <network> or 'join_all'
action="$2"	# e.g. join|join_all

[ -z "$network" ] && {
	echo "Usage: $0 <network|join_all> <join>"
	echo
	echo "content will be safed in ~/.ssh/authorized_keys.\$network"
	exit 1
}

case "$network" in 
	'join'*)
		ls -l $HOME/.ssh/authorized_keys.*
		cat $HOME/.ssh/authorized_keys.* >$HOME/.ssh/authorized_keys
		echo "[OK] all networks joined"
		exit
	;;
	*)
		[ -d "/var/www/networks/$network" ] || {
			echo "network '$network' unknown - aborting"
			exit 1
		}
	;;
esac

uptime_in_seconds()
{
	cut -d'.' -f1 /proc/uptime
}

up1="$( uptime_in_seconds )"
outfile="$HOME/.ssh/authorized_keys.$network"
logger -s "[START] safing to $outfile"

I=0
for file in /var/www/networks/$network/registrator/recent/* ; do {
	[ -e "$file" ] || continue

	I=$(( I + 1 ))
	. $file

	J=1
	while [ $J -lt ${#SSHPUBKEY} ]; do {
		HEXBYTE="$( echo "$SSHPUBKEY" | cut -b $J,$(( J + 1 )) )"
		J=$(( J + 2 ))

		[ ${#HEXBYTE} -eq 2 ] && {
			octal="$( printf "%o" "0x$HEXBYTE" )"
			eval printf "\\\\$octal"
		}
	} done
} done >"$outfile"

up2="$( uptime_in_seconds )"
logger -s "[READY] safed to $outfile in $(( up2 - up1 )) seconds ($I keys)"

[ -n "$action" ] && $0 "$action"
