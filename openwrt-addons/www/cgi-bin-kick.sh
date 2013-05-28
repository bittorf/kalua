#!/bin/sh
. /tmp/loader

echo -en "Content-type: text/plain\n\nOK"

eval $( _http query_string_sanitize )	# CAH|CMA

_netfilter user_probe "$CMA" || exit 1

[ -e "/tmp/vds_user_$CMA" ] || exit 1

read HASH <"/tmp/vds_user_$CMA"
[ "$HASH" = "$CAH" ] || exit

_scheduler add "_netfilter user_del $CMA"
