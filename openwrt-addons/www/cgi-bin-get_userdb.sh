#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\n"

_ipsystem include
NODE="$( _ipsystem do "$REMOTE_ADDR" )"
eval $( _ipsystem do "$NODE" | grep "[N|I]ADR=" )

case "$REMOTE_ADDR" in
	# fixme!
	$WANADR|$LANADR|$WIFIADR|192.168.*)
		# why tac? it's likely, that we grep for a new login - this should match faster
		# this is >1 magnitude faster than sed-tac

		if [ -e "/tmp/FREE" ]; then
			echo "# OK - FREE"
		else
			if grep -n '' /tmp/DB/USER/login/meta_index | sort -rn | cut -d: -f2- ; then
				echo "# OK"
			else
				echo "# ERROR: could not read"
			fi
		fi
	;;
	*)
		echo "# ERROR: Download from '$REMOTE_ADDR' not allowed"
	;;
esac
