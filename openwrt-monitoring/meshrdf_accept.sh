#!/bin/sh

if [ -n "$1" ]; then
#	echo "$1" >"/dev/shm/accept_$$"
#	if command . "/dev/shm/accept_$$"; then
		# we need WIFIMAC and WIFISCAN
		eval $1
#	else
#		logger -t $0 -p user.info "[ERR] eval $1"
#	fi
#
#	rm "/dev/shm/accept_$$"
else
	exit 0
fi

if [ -n "$LOG" ]; then
	# outdated: we write to '/tmp/monilog.txt' - see $0.php
	echo "$1" >>./meshrdf.txt
	echo "$UNIXTIME|$HOSTNAME|$WIFIMAC|$LOG" >>../log/log.txt
else
#	TEMPFILE="/tmp/write_meshrdf.${SSHPUBKEYFP:-$( date +%s )}.$$.tmp"
#	echo "$PUBIP_REAL"  >"$TEMPFILE"
#	mv "$TEMPFILE" ../pubip.txt || rm "$TEMPFILE"
#
	echo "$PUBIP_REAL" >../pubip.txt

	[ -z "$NEIGH" ] && {
		OLD_NEIGH="$( sed -n 's/^.*\(NEIGH=.*\);LAT.*/\1/p' "./recent/$WIFIMAC" )"
		[ "$OLD_NEIGH" = 'NEIGH=""' ] && OLD_NEIGH=
	}

	echo "$1" >>"./meshrdf.txt"
	echo -n "$1"  >"./recent/$WIFIMAC"
	[ -n "$OLD_NEIGH" ] && {
		echo "$PROFILE - $WIFIMAC" >>/tmp/BLA
		echo -n ";$OLD_NEIGH;LATFAKE=" >>"./recent/$WIFIMAC"
	}

	[ -n "$WIFISCAN" ] && {
		echo "# $(date)" >>"./recent/$WIFIMAC.wifiscan"
		echo "$WIFISCAN" >>"./recent/$WIFIMAC.wifiscan"
	}

	[ -e "./recent/${WIFIMAC}.changes" ] && rm "./recent/${WIFIMAC}.changes"

	case "$WIFIMAC" in
		b0487ac5d9ba|d85d4c9c2f1a|106f3f0e31aa|002590382edc|76ea3ae44a96)	# fparkssee | liszt28-buero | boltenhagendh | ejbw-pbx | F36-keller
			echo "$PUBIP_REAL" >./recent/$WIFIMAC.pubip

			logger -s "WIFIMAC: SPECIAL: '$WIFIMAC' pwd: $( pwd ) file: $( ls -l ./recent/$WIFIMAC.pubip )"

			cat >"./recent/$WIFIMAC.js" <<EOF
{
	"up": true,
	"hostname": "$HOSTNAME",
	"ipv4-address": [
		{
			"address": "$PUBIP_REAL",
			"mask": 32
		}
	],
	"ipv6-address": [

	]
}
EOF
		;;
		*)
#			logger -s "WIFIMAC: '$WIFIMAC'"
		;;
	esac
fi

exit 0
