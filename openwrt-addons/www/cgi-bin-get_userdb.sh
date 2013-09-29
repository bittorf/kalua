#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\n"

_ipsystem include
NODE="$( _ipsystem do "$REMOTE_ADDR" )"
eval $( _ipsystem do "$NODE" | grep "[N|I]ADR=" )

# ip route | fgrep "10.63.6.3 via "

case "$REMOTE_ADDR" in
	192.168.*)
		# fixme!
	;;
	$WANADR|$LANADR|$WIFIADR)
	;;
	*)
		# simple way for ensure, that only real nodes (OLSR/Mid) can do this
		ip route | fgrep -q "$REMOTE_ADDR via " || {
			echo "# ERROR: Download from '$REMOTE_ADDR' not allowed"
			exit 0
		}
	;;
esac

if [ -e "/tmp/FREE" ]; then
	echo "# OK - FREE"
else
	# why tac? it's likely, that we grep for a new login - this should match faster
	# this is >1 magnitude faster than sed-tac
	if grep -n '' /tmp/DB/USER/login/meta_index | sort -rn | cut -d: -f2- ; then
		echo "# OK"
	else
		echo "# ERROR: could not read"
	fi
fi
