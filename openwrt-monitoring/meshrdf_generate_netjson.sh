#!/bin/sh

NETWORK="${1:-$( pwd )}"
UNIX_NOW="$( date +%s )"

log()
{
:
	set -x
	set +x $1
}

update_local_netjson_files()
{
	local file url
	local base='/var/www/scripts'
#	local repo='https://raw.githubusercontent.com/interop-dev/netjsongraph.js'
	local repo='https://raw.githubusercontent.com/bittorf/netjsongraph.js'
	local insecure='--no-check-certificate'

	fetch()
	{
		wget $insecure -O "$file" "$url"
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

	local myjson='map.json'
	sed -i "s/\(d3.netJsonGraph(\"\).*.json\(.*\)/\1${myjson}\2/" "$file"

	# remove relative links, everything is 'here'
	sed -i 's|../src/||g' "$file"

	local mirror='https://cdnjs.cloudflare.com/ajax/libs/d3/3.5.5/d3.min.js'
	sed -i "s|../lib/d3.min.js|$mirror|" "$file"
}

[ "$1" = 'update' ] && {
	update_local_netjson_files
	exit
}

file_too_old()
{
	test $(( UNIX_NOW - $( date +%s -r "$1" ) )) -gt 86400
}

mac_filtered()
{
	. $1
	func_mac_is_filtered "$WIFIMAC"
}

file_ok()
{
	test -r "$1" || return 1
	file_too_old "$1" && return 1
	mac_filtered "$1" && return 1
	. $FILE && {
		test -n "$v2" || return 1	# only if git-version available, otherwise it's a cam or something alike
		test $v2 -gt 30000 || {
			log "v2: $v2 - $FILE"	# ignore svn on PBX (which is ~2800)

			case "$NETWORK" in
				*'monami'*)
					log "simulating good for 'monami'"
					return 0
				;;
				*)
					return 1
				;;
			esac
		}
	}
}

mac2linklocal()
{
	local mac="$( echo "$1" | sed 's/\(\w\w\)\(\w\w\)\(\w\w\)\(\w\w\)\(\w\w\)\(\w\w\)/\1:\2:\3:\4:\5:\6/g' )"
	local oldIFS="$IFS"; IFS=':'; set -- $mac; IFS="$oldIFS"
	printf "fe80::%x:%x:%x:%x\n" $(( 0x${1}${2} ^ 0x200 )) 0x${3}ff 0xfe${4} 0x${5}${6}
}

interpret_neigh()
{
	# see: olsr_neighs_meshrdf_evalable()
	# ~5:10.63.4.1:10.63.5.1:COST:1.000:1.000:1.000:1:12:7.2:5180:5-40:10.63.4.33:10.63.40.33:COST:1.000:1.000:0.100:1:0:7.2:2146:20

	local varname="$1"
	local line="$2"

	local old_ifs="$IFS"; IFS=':'; set -- $line; IFS="$old_ifs"

	case "$varname" in
		ip_local)
			echo "$2"
		;;
		ip_remote)
			echo "$3"
		;;
		nneigh)
			echo "$1" | cut -b2-	# ~6 -> 6
		;;
		ncost)
			echo "$7"
		;;
		ndev)
			echo "$1" | cut -b1	# ~6 -> ~
		;;
		'link_frequency')
			echo "${11}"
		;;
		'link_chanbw')
			echo "${12}"
		;;
		'link_carrier')
			case "$( echo "$1" | cut -b1 )" in
				'~')
					echo 'wireless'		# TODO: b/g/a/n/ac + bluetooth + zigbee...
				;;
				'-')
					echo 'ethernet'
				;;
				'=')
					echo 'tunnel'
				;;
				*)
					echo 'unknown'
				;;
			esac
		;;
		tx_rate)
			echo "$9"
		;;
		tx_throughput)
			echo "${10}"
		;;
		tx_both)
			echo "$9/${10}mbit"
		;;
	esac
}

func_interpret_neigh()		# NEIGH="~ 909 : 10.63.156.193 : 10.63.144.193 : COST : 0.360 : 0.372 : 7.439 : 2 : 12 : 5.5"
{
	local CONSTRUCT="$2"
	local ELEMENT="$1"

#	log "interpret_neigh: conctruct: '$CONSTRUCT' element: '$ELEMENT'"

	case $ELEMENT in
		nneigh)
			echo $CONSTRUCT | cut -d: -f1 | cut -b2-
		;;
		ncost)
			echo $CONSTRUCT | cut -d: -f7
		;;
		ndev)
			echo $CONSTRUCT | cut -b1
		;;
		tx_rate)
			echo $CONSTRUCT | cut -d: -f9
		;;
		tx_throughput)
			echo $CONSTRUCT | cut -d: -f10
		;;
		tx_both)
			echo "$( echo $CONSTRUCT | cut -d: -f9 )/$( echo $CONSTRUCT | cut -d: -f10 )mbit"
		;;
	esac
}

func_mac_is_filtered ()
{
	grep -q ^"$1" ../ignore/macs.txt && return 0
	return 1
}

func_nodenumber2hostname()	# 982 = "E1-116-AP"
{
#	log "nodenumber2hostname: $1 map.temp.node2hostname $( test -e map.temp.node2hostname || echo fehlt )"

	grep -s ^"$1 " map.temp.node2hostname | head -n1 | cut -d' ' -f2
}

func_hostname_short ()		# E3-323-MESH = E3-323 ... E1-116-AP = E1-116
{
	local HOSTNAME="$1"
	local OUT

	OUT="$( echo $HOSTNAME | sed -n 's/^\(.*-.*\)-.*/\1/p' )"
	[ -z "$OUT" ] && OUT="$HOSTNAME"

	echo "$OUT"
}

func_node_is_wired_with_node_in_ap_mode ()
{
	# FIXME!
	return 1
}

cat <<EOF
{
	"type": "NetworkGraph",
	"label": "bittorf wireless ))",
	"protocol": "OLSR",
	"topology_id": "$NETWORK@$(date)",
	"version": "1",
	"metric": "etx_ffeth",
	"nodes": [
EOF

FILELIST="$( find recent/ -type f | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ )"

for FILE in $FILELIST; do {		# preselect interesting nodes (e.g. only adhoc)
	file_ok "$FILE" || continue

	print()
	{
		# see func_nodenumber2hostname()
		case "$NETWORK" in
			*'schoeneck'*)
				# a lot of lines like:
				# node  79 is HausA-1804-MESH

				set -- $( grep " $NODE is" /var/www/networks/schoeneck/schoeneck-hostnames.sh )
				HOSTNAME="${4:-no_hostname}"
			;;
		esac

		echo "$NODE $HOSTNAME"

		{
			# TODO: build dynamically
			# FIXME - ejbw
			echo "172.17.0.2 50"
			echo "192.168.0.1 43"

			# monami
			echo '192.168.2.10 6'
			echo '192.168.2.102 7'

			echo "10.63.$NODE.1 $NODE"
			echo "10.63.$NODE.3 $NODE"
			echo "10.63.$NODE.25 $NODE"
			echo "10.63.$NODE.33 $NODE"
			echo "10.63.$NODE.57 $NODE"
			echo "10.63.$NODE.58 $NODE"
			echo "10.63.$NODE.61 $NODE"

			echo "10.10.$NODE.1 $NODE"
			echo "10.10.$NODE.3 $NODE"
			echo "10.10.$NODE.5 $NODE"
			echo "10.10.$NODE.7 $NODE"
			echo "10.10.$NODE.25 $NODE"
			echo "10.10.$NODE.33 $NODE"
			echo "10.10.$NODE.57 $NODE"
			echo "10.10.$NODE.58 $NODE"
			echo "10.10.$NODE.61 $NODE"
			echo "10.10.$NODE.125 $NODE"
			echo "10.10.$NODE.129 $NODE"
		} >>'map.temp.ip2id'

#		log "map.temp.node2hostname: NODE '$NODE' HOSTNAME '$HOSTNAME' WIFIMAC: '$WIFIMAC'"

		output_bool_isgateway()
		{
			if [ "$GWNODE" = "$NODE" ]; then
				echo 'true'
			else
				echo 'false'
			fi
		}

		{
			if [ "$FIRST_ID" ]; then
				echo ','
			else
				FIRST_ID='true'
			fi

			# TODO: 'id' = 'sshpubkey'?
			# TODO: local_addresses: dynamic
			cat <<EOF
		{
			"id": "$NODE",
			"label": "$HOSTNAME ($NODE)",
			"local_addresses": [
				"10.63.$NODE.1",
				"10.63.$NODE.33",
				"$( mac2linklocal "$WIFIMAC" )"
			],
			"properties": {
				"gateway": $( output_bool_isgateway ),
				"hostname": "$HOSTNAME",
				"wifimac": "$WIFIMAC",
				"hardware": "$HW",
				"ssh_pub_key": "$SSHPUBKEYFP",
				"dataset": "<a href='recent/$WIFIMAC'>clickme<\/a>",
				"nexthop": "${GWNODE:-0}",
				"speed_download": "${SENS:-0}",
				"clients": {
					"wifi_2ghz": ${r4:-0},
					"wifi_5ghz": 0,
					"wifi_total": ${r4:-0},
					"ethernet": ${r5:-0},
					"bluetooth": 0,
					"total": $(( ${r4:-0} + ${r5:-0} ))
				}
			}
EOF
			echo -n '		}'
		} >>map.temp.node2hostnameIDS
	}

#	case "$WIFIMODE" in
#		adhoc*|mac80211|ath9k-mac80211)
			print
#		;;
#	esac
} done >map.temp.node2hostname

cat map.temp.node2hostnameIDS
rm  map.temp.node2hostnameIDS
echo
echo "	],"
echo '	"links": ['

#for FILE in $FILELIST; do {						# describe each node (shape, label, color ...)
for FILE in NULL; do {
	continue	# ignore block
	. $FILE

	log "func_nodenumber2hostname $NODE"

	[ -n "$( func_nodenumber2hostname $NODE )" ] && {		# only preselected nodes for small topo

		LABEL="$( func_hostname_short $HOSTNAME )"

		if [ "$COST2GW" = "1.000" ]; then
			COST=
		else
			COST="\ncost: $COST2GW"
		fi

		if func_node_is_wired_with_node_in_ap_mode; then
			SHAPE="doublecircle"
		else
			SHAPE="circle"
		fi

		cat <<EOF
	"$( func_nodenumber2hostname $NODE )" [ shape=$SHAPE, label="${LABEL}${COST}" ];
EOF
	}
} done

[ -e ./map.temp.conns ] && rm ./map.temp.conns

for FILE in NULL; do {
	continue	# ignore this block
#for FILE in $FILELIST; do {		# describe all connections, which are used for inet ("path to gateway")
	. $FILE

	log "neigh: $NEIGH"

	echo "$NEIGH" | while read LINE; do {

		case "$LINE" in
			[=~-]*)
			;;
			*)
				continue
			;;
		esac
#		log "neighline: $LINE"

		NDEV="$(   interpret_neigh "ndev"   "$LINE" )"
		NNEIGH="$( interpret_neigh "nneigh" "$LINE" )"
		NCOST="$(  interpret_neigh "ncost"  "$LINE" )"

		LOCAL="$(  func_nodenumber2hostname $NODE )"
		REMOTE="$( func_nodenumber2hostname $NNEIGH )"
		COST="$( echo ${NCOST:=infinite} | sed 's/[^0-9]//g' )"		# 1.782 = 1782 for floatless calculating
		[ -z "$COST" ] && COST="9999"

#		log "cost: $COST local: $LOCAL remote: $REMOTE"

		# only interesting neighbours/connections
		if [ -z "$LOCAL" -o -z "$REMOTE" ]; then continue; fi

		# only show connections to my gateway
		[ "$NNEIGH" != "$GWNODE" ] && continue

		  if [ "$NDEV" = "-" ]; then					# fixme! make a func...
		  	STYLE="bold"
		elif [ $COST -lt 1500 ]; then
			STYLE="solid"
		elif [ $COST -lt 2000 ]; then
			STYLE="dashed"
		else
			STYLE="dotted"
		fi

		if [ $COST -gt 2000 ]; then
			LABEL=",label=\"${NCOST}\""
#			LABEL=",label=\"${NCOST}$( func_interpret_neigh tx_both $LINE )\""
		else
			LABEL=
#			LABEL=",label=\"$( func_interpret_neigh tx_both $LINE )\""
		fi

		echo "	\"$LOCAL\" -> \"$REMOTE\" [ arrowhead=\"normal\", arrowtail=\"inv\", style=$STYLE $LABEL];"

		echo >>map.temp.conns "$REMOTE $LOCAL"		# for avoiding double conns
		echo >>map.temp.conns "$LOCAL $REMOTE"	
	} done
} done

ip2id()
{
	fgrep -s "$1 " 'map.temp.ip2id' | head -n1 | cut -d' ' -f2
}

# all links
for FILE in $FILELIST; do {		# describe all connections, which are not used for inet, and are not described before
	file_ok "$FILE" || continue

	echo "$NEIGH" | sed 's/[=~-]/\n&/g' >"/tmp/links_$$"
	while read LINE; do {
		[ -z "$LINE" ] && continue

		NDEV="$(   func_interpret_neigh 'ndev'   "$LINE" )"	# e.g. '-' or '~'
		NNEIGH="$( func_interpret_neigh 'nneigh' "$LINE" )"
		NCOST="$(  func_interpret_neigh 'ncost'  "$LINE" )"

		LOCAL="$(  func_nodenumber2hostname "$NODE" )"
		REMOTE="$( func_nodenumber2hostname "$NNEIGH" )"

		COST="$( echo "$NCOST" | sed 's/[^0-9]//g' )"
		#
		IP_LOCAL="$(  interpret_neigh 'ip_local'  "$LINE" )"
		IP_REMOTE="$( interpret_neigh 'ip_remote' "$LINE" )"

[ -z "$IP_LOCAL" ] && log "$(pwd)/$FILE - zero ip_local"

#		[ -z "$LOCAL"  ] && continue
#		[ -z "$REMOTE" ] && continue

#		[ -z "$COST"     ] && continue
		[ "$COST" = '0100' ] && COST=100
#		[ $COST -gt 5000 ] && continue		# only good neighs for smaller topology


		# e.g. infinite
		[ -z "$COST" ] && {
			if [ "$NDEV" = '~' ]; then
				continue
			else
				log "$(pwd)/$FILE - '$IP_LOCAL' - zero COST/wired - '$LINE'"
#				continue
			fi
		}

		[ -z "$NCOST" ] && {
			log "$(pwd)/$FILE - '$IP_LOCAL' - zero NCOST - '$LINE'"
			NCOST=1
		}

		  if [ "$NDEV" = "-" ]; then
			STYLE="bold"
		elif [ $COST -lt 1500 ]; then
			STYLE="solid"
		elif [ $COST -lt 2000 ]; then
			STYLE="dashed"
		else
			STYLE="dotted"
		fi

		if [ $COST -gt 2000 ]; then
#			LABEL=",label=\"${NCOST:=infinite}\""
			LABEL=",label=\"${NCOST:=infinite}$( func_interpret_neigh tx_both $LINE )\""
		else
#			LABEL=
			LABEL=",label=\"$( func_interpret_neigh tx_both $LINE )\""
		fi

		ID_LOCAL="$(  ip2id "$IP_LOCAL"  )"
		ID_REMOTE="$( ip2id "$IP_REMOTE" )"
		[ -z "$ID_LOCAL" ] && {
			log "$(pwd)/$FILE - '$IP_LOCAL' - zero id_local - '$LINE'"
			continue
		}
		[ -z "$ID_REMOTE" ] && {
			log "$(pwd)/$FILE - '$IP_REMOTE' - zero id_remote - '$LINE'"
			continue
		}

		# avoiding double conns
		grep -sq ^"$ID_LOCAL $ID_REMOTE" ./map.temp.conns && {
#			log "[OK] already plotted: '$ID_LOCAL $ID_REMOTE'"
			continue
		}

		if [ -n "$FIRST_LINK" ]; then
			echo ','
		else
			FIRST_LINK='true'
		fi

		link_carrier="$(   interpret_neigh 'link_carrier'   "$LINE" )"
		link_frequency="$( interpret_neigh 'link_frequency' "$LINE" )"
		link_chanbw="$(    interpret_neigh 'link_chanbw'    "$LINE" )"

		[ "$link_carrier" = 'wireless' ] && {
			[ $COST -gt 3000 ] && {
#				log "$(pwd)/$FILE - weak - '$LINE'"
				link_carrier='wireless_weak'
			}
		}

		if [ "$link_frequency" = '0' -o -z "$link_frequency" ]; then
			comma=
		else
			comma=','
		fi

		cat <<EOF
		{
			"source": "$ID_LOCAL",
			"target": "$ID_REMOTE",
			"cost": $NCOST,
			"properties": {
				"type": "$link_carrier",
				"carrier": "$link_carrier"${comma}
EOF
		[ -n "$comma" ] && {
			cat <<EOF
				"frequency": "$link_frequency",
				"chanbw": "$link_chanbw"
EOF
		}

		cat <<EOF
			}
EOF
		echo -n '		}'

#		echo "	\"$LOCAL\" -> \"$REMOTE\" [ arrowhead=\"none\", arrowtail=\"none\", style=$STYLE $LABEL];"
		
		echo "$ID_LOCAL $ID_REMOTE" >>map.temp.conns
		echo "$ID_REMOTE $ID_LOCAL" >>map.temp.conns
	} done <"/tmp/links_$$"
} done

echo
echo "	]"
echo "}"

rm 2>/dev/null ./map.temp.node2hostname ./map.temp.conns map.temp.ip2id "/tmp/links_$$"
