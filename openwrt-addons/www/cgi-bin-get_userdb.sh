#!/bin/sh
. /tmp/loader

# e.g. REMOTE_ADDR=10.10.147.1 -> node=147 (or empty)
# Q: is $REMOTE_ADDR any of node-147 LAN/WAN/WIFI-address?

if _ipsystem get "$( _ipsystem get "$REMOTE_ADDR" )" | grep "[N|I]ADR=" | grep -q "=$REMOTE_ADDR"$ ; then
	:
	# ok, remote is a real OLSR/Mid
else
	case "$REMOTE_ADDR" in
		192.168.*.1)
			# FIXME! should match batman-originators
		;;
		192.168.112.2|172.17.0.1)
			# FIXME! (ejbw)
		;;
		$LOADR)
			# localhost
		;;
		*)
			_net is_router "$REMOTE_ADDR" || {
				_http header_mimetype_output text/plain
				echo "# ERROR: Download from '$REMOTE_ADDR' not allowed"
				exit 0
			}
		;;
	esac
fi

db_needed()
{
	test -e "$TMPDIR/FREE_LOCALLY" && return 0
	test -e '/tmp/FREE' && return 1

	return 0
}

if db_needed; then
	# generated via '_db_restore()'
	touch '/tmp/USERDB_COPY.cgi.gz'

	case "$QUERY_STRING" in
		*'bonehead'|*'broken302redirect')
			# old clients with r35300 or lower (do not understund http_redirect)
			# and uclient-fetch r48386+ seems also broken
			_http header_mimetype_output 'text/plain'
			cat '/tmp/USERDB_COPY.cgi.gz'
		;;
		*)
			if [ "$REMOTE_ADDR" = "$LOADR" ]; then
				_http header_mimetype_output 'text/plain'
				echo '# OK - ignore localhost'
			else
				if [ -s '/tmp/USERDB_COPY.cgi.gz' ]; then
					_http redirect 302 '/USERDB_COPY.txt'
				else
					if [ -s '/tmp/USERDB_COPY' -a -e '/tmp/USERDB_COPY.speed' ]; then
						# deliver my local copy
						_http header_mimetype_output 'text/plain'
						cat '/tmp/USERDB_COPY'
					else
						_http header_mimetype_output 'text/plain'
						echo '# ERR - db missing'
						echo >>$SCHEDULER_IMPORTANT '_db restore'
					fi
				fi
			fi
		;;
	esac
else
	_http header_mimetype_output 'text/plain'
	echo '# OK - FREE'
fi
