#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\n"

_ipsystem include
NODE="$( _ipsystem do "$REMOTE_ADDR" )"
eval $( _ipsystem do "$NODE" | grep "[N|I]ADR=" )

case "$REMOTE_ADDR" in
	$WANADR|$LANADR|$WIFIADR)
		case "$QUERY_STRING" in
			*tac)
				COMMAND="sed '1!G;h;$!d' /tmp/DB/USER/login/meta_index"
			;;
			*)
				COMMAND="cat /tmp/DB/USER/login/meta_index"
			;;
		esac

		if $COMMAND; then
			echo "# OK"
		else
			echo "# ERROR: could not read"
		fi
	;;
	*)
		echo "# ERROR: Download from '$REMOTE_ADDR' not allowed"
	;;
esac
