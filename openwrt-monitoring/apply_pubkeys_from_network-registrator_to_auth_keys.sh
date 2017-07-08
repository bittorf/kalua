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
logger -s "[START] safing to '$outfile'"

I=0
K=0
for file in /var/www/networks/$network/registrator/recent/* ; do {
	[ -e "$file" ] || continue

	. $file		# getting SSHPUBKEY and NODE and WIFIMAC

	I=$(( I + 1 ))	# how many keys are read
	J=1
	while [ $J -lt ${#SSHPUBKEY} ]; do {
		# convert hex2bin, always 2 bytes
		HEXBYTE="$( echo "$SSHPUBKEY" | cut -b $J,$(( J + 1 )) )"
		J=$(( J + 2 ))

		[ ${#HEXBYTE} -eq 2 ] && {
			octal="$( printf "%o" "0x$HEXBYTE" )"
			eval printf "\\\\$octal"
		}
	} done >"$outfile.tmp"

	read -r KEY <"$outfile.tmp"
	grep -q -- ^"$KEY"$ "$outfile" || {
		K=$(( K + 1 ))
		logger -s "[OK] adding new/changed key for node '$NODE/$WIFIMAC' from '$file'"
		echo "$KEY" >>"$outfile"
	}
} done

up2="$( uptime_in_seconds )"

if [ $K -eq 0 ]; then
	logger -s "[OK] no new keys found"
else
	logger -s "[READY] safed to '$outfile' in $(( up2 - up1 )) seconds ($I keys/$K added)"

	[ -n "$action" ] && $0 "$action"
fi
