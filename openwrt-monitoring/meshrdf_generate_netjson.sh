#!/bin/sh

NETWORK="${1:-$( pwd )}"
UNIX_NOW="$( date +%s )"

log()
{
:
	set -x
	set +x $1
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

	return 0
}

interpret_neigh()
{
	# ~5:10.63.4.1:10.63.5.1:COST:1.000:1.000:1.000:1:12:7.2:g-40:10.63.4.33:10.63.40.33:COST:1.000:1.000:0.100:1:0:7.2:g
	local varname="$1"
	local line="$2"
	local old_ifs

	old_ifs="$IFS"; IFS=":"; set -- $line; IFS="$old_ifs"

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

SERVER_UNIXTIME="$( date +%s )"

for FILE in $FILELIST; do {		# preselect interesting nodes
	file_ok "$FILE" || continue
        . $FILE
	[ "$NODE" = '0' ] && continue	# camserver giancarlo

#	log "wifimode: $WIFIMODE"

	print()
	{
		# see func_nodenumber2hostname()
		echo "$NODE $HOSTNAME"

		{
			# TODO: build dynamically
			echo "10.63.$NODE.1 $NODE"
			echo "10.63.$NODE.3 $NODE"
			echo "10.63.$NODE.25 $NODE"
			echo "10.63.$NODE.33 $NODE"
			echo "10.63.$NODE.61 $NODE"

			echo "10.10.$NODE.1 $NODE"
			echo "10.10.$NODE.3 $NODE"
			echo "10.10.$NODE.25 $NODE"
			echo "10.10.$NODE.33 $NODE"
			echo "10.10.$NODE.61 $NODE"
			echo "10.10.$NODE.129 $NODE"
		} >>'map.temp.ip2id'

#		log "map.temp.node2hostname: NODE '$NODE' HOSTNAME '$HOSTNAME' WIFIMAC: '$WIFIMAC'"

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
			"label": "node-$NODE",
			"local_addresses": [
				"10.63.$NODE.1",
				"10.63.$NODE.33"
			],
			"properties": {
				"hostname": "$HOSTNAME",
				"wifimac": "$WIFIMAC"
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
	. $FILE
	[ "$NODE" = '0' ] && continue	# camserver giancarlo

	echo $NEIGH | sed 's/[=~-]/\n&/g' >"/tmp/links_$$"
	while read LINE; do {
		[ -z "$LINE" ] && continue

		NDEV="$(   func_interpret_neigh 'ndev'   "$LINE" )"
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


		[ -z "$COST" ] && {
#			log "$(pwd)/$FILE - '$IP_LOCAL' - zero COST - '$LINE'"
			# e.g. infinite
			continue
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
#			log "[ERR] already known: '$ID_LOCAL $ID_REMOTE'"
			continue
		}

		if [ -n "$FIRST_LINK" ]; then
			echo ','
		else
			FIRST_LINK='true'
		fi

		cat <<EOF
		{
			"source": "$ID_LOCAL",
			"target": "$ID_REMOTE",
			"cost": $NCOST
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

rm 2>/dev/null ./map.temp.node2hostname ./map.temp.conns map.temp.ip2id

