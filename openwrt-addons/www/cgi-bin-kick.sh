#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\nOK"

eval $( _http query_string_sanitize )	# CAH|CMA|LOG

[ -n "$LOG" ] && {
	logger -s "$0: LOG: '$LOG'"
	exit 1
}

_netfilter user_probe "$CMA" || exit 1

[ -e "/tmp/vds_user_$CMA" ] || exit 1

read HASH <"/tmp/vds_user_$CMA"
[ "$HASH" = "$CAH" ] || exit

echo >>$SCHEDULER "_netfilter user_del $CMA"
