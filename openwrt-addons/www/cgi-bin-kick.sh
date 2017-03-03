#!/bin/sh
. /tmp/loader

_http header_mimetype_output 'text/plain'
echo 'OK'

eval $( _http query_string_sanitize "$0" )	# CAH|CMA|LOG

if [ -n "$LOG" ]; then
	_log it kicker daemon info "LOG: '$LOG'"
else
	_netfilter user_probe "$CMA" || exit 1

	nf_user 'is_known' "$CMA" || exit 1

	HASH=
	nf_user 'get_hash' "$CMA" 'HASH'
	[ "$HASH" = "$CAH" ] || exit

	echo >>$SCHEDULER "_netfilter user_del $CMA kick_user"
fi
