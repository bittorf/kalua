#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\nOK"
eval $( _http query_string_sanitize "$0" )	# CAH|CMA|LOG

if [ -n "$LOG" ]; then
	logger -s -- "$0: LOG: '$LOG'"
else
	_netfilter user_probe "$CMA" || exit 1

	[ -e "/tmp/vds_user_$CMA" ] || exit 1

	read -r HASH <"/tmp/vds_user_$CMA"
	[ "$HASH" = "$CAH" ] || exit

	echo >>$SCHEDULER "_netfilter user_del $CMA kick_user"
fi
