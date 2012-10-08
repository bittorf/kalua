#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\n"

_ipsystem include
NODE="$( _ipsystem do "$REMOTE_ADDR" )"
eval $( _ipsystem do "$NODE" | grep "[N|I]ADR=" )

case "$REMOTE_ADDR" in
	$WANADR|$LANADR|$WIFIADR)
		if cat /tmp/DB/USER/login/meta_index; then
			echo "# OK"
		else
			echo "# ERROR: could not read"
		fi
	;;
	*)
		echo "# ERROR: Download from '$REMOTE_ADDR' not allowed"
	;;
esac
