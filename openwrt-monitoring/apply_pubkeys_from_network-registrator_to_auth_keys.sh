#!/bin/bash

network="$1"	# e.g. <network> or 'join_all'
action="$2"	# e.g. join|join_all

[ -z "$network" ] && {
	echo "Usage: $0 <network|join_all> <join>"
	echo
	echo "content will be safed in ~/.ssh/authorized_keys.\$network"
	exit 1
}

case "$network" in 
	"join"*)
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
	I=$(( I + 1 ))
	. $file
	echo "$SSHPUBKEY" >$file.temp

	case "$file" in
		*"0200cab10002"|*'106f3f0e31aa')
			logger -s "special MAC: file: $file - sshpubkey: $SSHPUBKEY"
		;;
	esac

	while read -r -n 2 hexbyte; do {
		[ ${#hexbyte} -eq 2 ] && {
			octal="$( printf "%o" "0x$hexbyte" )"
			eval printf "\\\\$octal"
		}
	} done <$file.temp

	rm $file.temp
} done >"$outfile"

up2="$( uptime_in_seconds )"
logger -s "[READY] safed to $outfile in $(( up2 - up1 )) seconds ($I keys)"

[ -n "$action" ] && $0 "$action"
