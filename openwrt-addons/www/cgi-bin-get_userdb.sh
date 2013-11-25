#!/bin/sh
. /tmp/loader

# e.g. REMOTE_ADDR=10.10.147.1 -> node=147 (or empty)
# Q: is $REMOTE_ADDR any of node-147 LAN/WAN/WIFI-address?

if _ipsystem do "$( _ipsystem do "$REMOTE_ADDR" )" | grep "[N|I]ADR=" | grep -q "=$REMOTE_ADDR"$ ; then
	:
	# ok, remote is a real OLSR/Mid
else
	case "$REMOTE_ADDR" in
		192.168.*.1)
			# fixme! should match batman-originators
		;;
		$LOADR)
			# localhost
		;;
		*)
			# simple way for ensure, that only real nodes (OLSR/Mid) can do this
			ip route | fgrep -q "$REMOTE_ADDR via " || {
				_http header_mimetype_output text/plain
				echo "# ERROR: Download from '$REMOTE_ADDR' not allowed"
				exit 0
			}
		;;
	esac
fi

if [ -e "/tmp/FREE" ]; then
	_http header_mimetype_output text/plain
	echo "# OK - FREE"
else
	# generate via '_db_restore()'
	touch '/tmp/USERDB_COPY.cgi.gz'

	case "$QUERY_STRING" in
		*'bonehead'*)
			_http header_mimetype_output 'text/plain'
			cat '/tmp/USERDB_COPY.cgi.gz'
		;;
		*)
			if [ "$REMOTE_ADDR" = "$LOADR" ]; then
				_http header_mimetype_output 'text/plain'
				echo "# OK - ignore localhost"
			else
				_http redirect 302 '/USERDB_COPY.txt'
			fi
		;;
	esac
fi
