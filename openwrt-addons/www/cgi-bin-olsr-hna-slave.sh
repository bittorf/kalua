#!/bin/sh
. /tmp/loader

knowing_hna_already()
{
	local funcname="knowing_hna_already"
	local netaddr="$1"
	local netmask="$( _net cidr2mask "$2" )"
	local i=0

	while true; do
		case "$( uci get olsrd.@Hna4[$i].netaddr)/$( uci get olsrd.@Hna4[$i].netmask )" in
			"$netaddr/$netmask")
				_log it $funcname daemon info "already know: $netaddr/$netmask"
				return 0
			;;
			'/')
				# empty output/end of list
				_log it $funcname daemon info "new hna: $netaddr/$netmask"
				return 1
			;;
		esac

		i=$(( i + 1 ))
	done
}

hna_add()
{
	local netaddr="$1"
	local netmask="$( _net cidr2mask "$2" )"
	local token="$( uci add olsrd Hna4 )"

	uci set olsrd.$token.netaddr="$netaddr"
	uci set olsrd.$token.netmask="$netmask"
}

add_static_routes()
{
	local ip="$1"
	local netaddr="$2"
	local netmask="$3"
	local dev="$4"

	[ -e "/tmp/OLSR/isneigh_$ip" ] && rm "/tmp/OLSR/isneigh_$ip"
	ip route add $netaddr/$netmask via $ip dev $dev metric 1 onlink
}

device_forbidden()
{
	local ip="$1"

	test -z "$ip"
}

_http header_mimetype_output "text/plain"

# var "$mode" comes via QUERY_STRING - see ask_for_slave() in
# /usr/sbin/cron.olsr-hna-slave and olsrd.@meta[0].hnaslave_dirty
if [ -e "/tmp/LOCK_OLSRSLAVE" -a "$mode" != 'dirty' ]; then
	[ $( _stopwatch stop '/tmp/LOCK_OLSRSLAVE' interim,nolog,seconds ) -gt 3600 ] || {
		_log it htmlout daemon info "sending LOCKED to $REMOTE_ADDR"
		echo "LOCKED"
		exit 0
	}
else
	touch "/tmp/LOCK_OLSRSLAVE"
fi

trap "rm /tmp/LOCK_OLSRSLAVE; exit" HUP INT QUIT TERM EXIT
_stopwatch start '/tmp/LOCK_OLSRSLAVE' global

if   device_forbidden "$REMOTE_ADDR"; then
	ERROR="NEVER"
elif _olsr uptime is_short; then
	ERROR="SHORT_OLSR_UPTIME"
elif [ ! -e '/tmp/OLSR/daemon_version' ]; then
	ERROR="SHORT_OLSR_UPTIME"
else
	netaddr=;netmask=;version=;mode=
	eval $( _http query_string_sanitize "$0" )		# ?netaddr=...&netmask=...&version=...

	if _sanitizer run "$version" numeric check; then
		RTABLE="$( ip route list exact $netaddr/$netmask | fgrep " via $REMOTE_ADDR " )" || {
			knowing_hna_already "$netaddr" "$netmask" && {
				RTABLE="$( ip route list exact $REMOTE_ADDR | fgrep " via $REMOTE_ADDR " )"
			}
		}

		test $version -ge $FFF_PLUS_VERSION || {
			RTABLE="slave_version_to_low:$version"
			ERROR="$RTABLE"
		}
	else
		RTABLE='error_in_version'
		ERROR="$RTABLE"
	fi

	case "$RTABLE" in
		'slave_version_to_low'*|'error_in_version')
			dev2slave=
		;;
		*" dev $LANDEV "*)
			dev2slave="$LANDEV"
			for DEV in $WANDEV $WIFIDEV; do {
				CHECK_IP="$( _net dev2ip $DEV )" && break
			} done
		;;
		*" dev $WANDEV "*)
			dev2slave="$WANDEV"
			for DEV in $LANDEV $WIFIDEV; do {
				CHECK_IP="$( _net dev2ip $DEV )" && break
			} done
		;;
		*)
			_log it cannot_find_your_hna daemon info "netaddr: $netaddr netmask: $netmask remote_addr: $REMOTE_ADDR = '$( ip route list exact $netaddr/$netmask )'"
			ERROR="CANNOT_FIND_YOUR_HNA"
		;;
	esac

	[ -n "$dev2slave" ] && {
		ERROR="OK $CHECK_IP"

		# does not hurt if we do it twice
		add_static_routes "$REMOTE_ADDR" "$netaddr" "$netmask" "$dev2slave"

		knowing_hna_already "$netaddr" "$netmask" || {
			hna_add "$netaddr" "$netmask"

			grep -sq "$REMOTE_ADDR" '/www/OLSR_has_neigh_LAN' && rm '/www/OLSR_has_neigh_LAN'
			grep -sq "$REMOTE_ADDR" '/www/OLSR_has_neigh_WAN' && rm '/www/OLSR_has_neigh_WAN'

			[ "$mode" = 'dirty' ] || {
				_olsr daemon restart "becoming hna-master for $REMOTE_ADDR: $netaddr/$netmask"
			}
		}
	}
fi

echo "${ERROR:=ERROR}"
_log it htmlout daemon info "errorcode: $ERROR for IP: $REMOTE_ADDR"

rm "/tmp/LOCK_OLSRSLAVE"
trap - HUP INT QUIT TERM EXIT
