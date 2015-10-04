#!/bin/sh
[ -e '/tmp/loader' ] && {
	. /tmp/loader
	_stopwatch start 'netjson'
}

# TODO: list of VPN-servers
# TODO: pattern for IP's of wired links
# TODO: gateways

NETWORK_NAME="$1"
FILE="${2:-/tmp/OLSR/ALL}"		# output of 'txtinfo'-plugin
TMP_JSON="${3:-/tmp/netjson_links.json}"
#
TMP_OLSR='/tmp/netjson_olsr.txt'
FILE_HOSTNAMES='/var/run/hosts_olsr'	# nameservice plugin

# for live generating via webserver:
# ln -s /usr/sbin/cron.build_netjson.sh /www/cgi-bin-netjson.sh
[ -z "$NETWORK_NAME" -a -n "$REMOTE_ADDR" ] && {
	echo -en "Content-type: application/json\n\n"
	NETWORK_NAME='live'
}

case "$NETWORK_NAME" in
	'')
		echo "Usage: $0 <networkname|setup_html> [<txtinfo-output>] [<tmpfile>]"
		echo
		echo "  e.g. $0 ffweimar  (if arg2 or arg3 is omitted, we take care of)"
		echo "       $0 ffleipzig >/var/www/map.json"
		echo "       $0 setup_html /www    (will copy all needed netjson-files)"

		exit 1
	;;
	'setup_html')
		update_local_netjson_files()
		{
			local file url dir
			local base="${1:-/www}"
			local repo='https://raw.githubusercontent.com/interop-dev/netjsongraph.js/master'
		#	local repo='https://raw.githubusercontent.com/bittorf/netjsongraph.js/master'
			local myjson='map.json'

			fetch()
			{
				# github https is often broken
				curl --silent --insecure "$url" -o "$file" || echo "[ERR] curl '$url'"
			}

			url="$repo/src/netjsongraph.js"
			file="$base/$( basename "$url" )"
			fetch

			url="$repo/src/netjsongraph.css"
			file="$base/$( basename "$url" )"
			fetch

			url="$repo/src/netjsongraph-theme.css"
			file="$base/$( basename "$url" )"
			fetch

			# our index.html
			url="$repo/examples/custom-attributes.html"
			file="$base/netjson.html"
			fetch

			# reference my 'netjson file'
			sed -i "s/\(d3.netJsonGraph(\"\).*.json\(.*\)/\1${myjson}\2/" "$file"

			# remove relative links, everything is 'here'
			sed -i 's|../src/||g' "$file"

			local mirror='https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.5/d3.min.js'
			sed -i "s|../lib/d3.min.js|$mirror|" "$file"
		}

		dir="$FILE"
		mkdir -p "$dir"
		update_local_netjson_files "$FILE"

		exit 0
	;;
esac

[ -e "$FILE" ] || {
	FILE="$TMP_OLSR"
	wget -qO "$FILE" 'http://127.0.0.1:2006/all' || exit 1
}

add_node_if_unknown()
{
	case " $LIST_NODES " in
		*" $1 "*)
		;;
		*)
			LIST_NODES="$LIST_NODES $1"
		;;
	esac
}

update_local_netjson_files()
{
	local file url
	local base="${1:-/www}"
	local repo='https://raw.githubusercontent.com/interop-dev/netjsongraph.js'
#	local repo='https://raw.githubusercontent.com/bittorf/netjsongraph.js'
	local myjson='map.json'

	fetch()
	{
		wget --no-check-certificate  -O "$file" "$url"
	}

	url="$repo/master/src/netjsongraph.js"
	file="$base/$( basename "$url" )"
	fetch

	url="$repo/master/src/netjsongraph.css"
	file="$base/$( basename "$url" )"
	fetch

	url="$repo/master/src/netjsongraph-theme.css"
	file="$base/$( basename "$url" )"
	fetch

	url="$repo/master/examples/custom-attributes.html"
	file="$base/netjson.html"
	fetch

	# reference my 'netjson file'
	sed -i "s/\(d3.netJsonGraph(\"\).*.json\(.*\)/\1${myjson}\2/" "$file"

	# remove relative links, everything is 'here'
	sed -i 's|../src/||g' "$file"

	local mirror='https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.5/d3.min.js'
	sed -i "s|../lib/d3.min.js|$mirror|" "$file"
}

PARSE='false'				# here we read in the 'Topology' table once
while read LINE; do {			# and extract all nodes and all links
	case "$LINE" in
		'Table: Topology'*)
			unset PARSE
			continue
		;;
	esac

	case "$PARSE" in
		'')
			case "$LINE" in
				[0-9]*)
					# 10.10.3.33  10.10.4.33  0.784  0.117  INFINITE
					# 10.10.4.33  10.10.3.33  0.152  0.819  7.978
					set -- $LINE

					COST="$5"
					case "$COST" in
						'INFINITE')
							COST='"NULL"'
						;;
					esac

					add_node_if_unknown "$1"	# local IP
					add_node_if_unknown "$2"	# remote IP

					test -n "$BUFFER" && echo "$BUFFER,"
					BUFFER="    { \"source\": \"$1\", \"target\": \"$2\", \"cost\": $COST }"
				;;
				'')
					echo "$BUFFER" && BUFFER=
					break
				;;
			esac
		;;
	esac
} done <"$FILE" >"$TMP_JSON"

[ -e "$FILE_HOSTNAMES" ] && {
	while read LINE; do {
		case "$LINE" in
			[0-9]*)
				# 10.63.160.161  AlexLaterne    # 10.63.160.161
				set -- $LINE
				IP="$1"
				NAME="$2"

				eval IP_${IP//./_}="$NAME"	# e.g. IP_1_2_3_4='foo'
			;;
		esac
	} done <"$FILE_HOSTNAMES" 2>/dev/null
}

# output header
cat <<EOF
{
  "type": "NetworkGraph",
  "label": "$NETWORK_NAME with <a href='http://netjson.org'>netJSON.org</a>",
  "protocol": "OLSR",
  "topology_id": "$NETWORK_NAME@$( date "+%d.%b'%y-%H:%M" )",
  "version": "1",
  "metric": "$( uci -q get olsrd.@olsrd[0].LinkQualityAlgorithm || echo 'etx_ffeth' )",
  "nodes": [
EOF


for IP in $LIST_NODES; do {
	eval NAME="\$IP_${IP//./_}"
	test -n "$BUFFER" && echo "$BUFFER,"
	BUFFER="    { \"id\": \"$IP\", \"label\": \"${NAME:-$IP}\" }"
} done
echo "$BUFFER"

echo '  ],'
echo '  "links": ['

# output links:
cat "$TMP_JSON" 2>/dev/null && rm "$TMP_JSON"

echo '  ]'
echo '}'

[ -e '/tmp/loader' ] && _stopwatch stop 'netjson' quiet
