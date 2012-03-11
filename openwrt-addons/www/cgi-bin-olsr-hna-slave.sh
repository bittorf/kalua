#!/bin/sh
. /tmp/loader

knowing_hna_already()
{
	local netaddr="$1"
	local netmask="$( _net cidr2mask "$2" )"

	return 1
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

	ip route add $ip via $ip dev $dev metric 1 onlink
	ip route add $netaddr/$netmask via $ip dev $dev metric 1 onlink
}

eval $( _http query_string_sanitize )

case "$( ip route list exact $netaddr/$netmask | fgrep " via $REMOTE_ADDR " )" in
	*" dev $LANDEV "*)
		dev2slave="$LANDEV"
	;;
	*" dev $WANDEV "*)
		dev2slave="$WANDEV"
	;;
esac

[ -n "$dev2slave" ] && {
	knowing_hna_already "$netaddr" "$netmask" || {
		hna_add "$netaddr" "$netmask"
		add_static_routes "$REMOTE_ADDR" "$netaddr" "$netmask" "$dev2slave"
		_olsr daemon restart "becoming hna-master for $REMOTE_ADDR: $netaddr/$netmask"
		ERROR="OK"
	}
}

_http header_mimetype_output "text/html"
echo "${ERROR:-ERROR}"
