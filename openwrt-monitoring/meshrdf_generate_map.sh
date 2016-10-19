#!/bin/sh

[ -n "$1" ] && {
	# e.g. /var/www/networks/liszt28/meshrdf
	cd "$1" || exit
}

log()
{
	:
#	logger -s "$0: $1"
#	echo >>/tmp/leo.txt "$0: $1"
}

interpret_neigh()
{
	# see: _olsr_neighs_meshrdf_evalable()
	# ~5:10.63.4.1:10.63.5.1:COST:1.000:1.000:1.000:1:12:7.2:g-40:10.63.4.33:10.63.40.33:COST:1.000:1.000:0.100:1:0:7.2:g
	local varname="$1"
	local line="$2"
	local old_ifs

	old_ifs="$IFS"; IFS=":"; set -- $line; IFS="$old_ifs"

	case "$varname" in
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

	log "interpret_neigh: conctruct: '$CONSTRUCT' element: '$ELEMENT'"

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

func_nodenumber2hostname ()	# 982 = "E1-116-AP"
{
	log "nodenumber2hostname: $1 map.temp.node2hostname $( test -e map.temp.node2hostname || echo fehlt )"

	grep ^"$1 " map.temp.node2hostname | head -n1 | cut -d' ' -f2
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
	return 0
}

echo "digraph network {"

FILELIST="$( find recent/ -type f | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ )"

SERVER_UNIXTIME="$( date +%s )"

for FILE in $FILELIST; do {		# preselect interesting nodes
        . $FILE

        func_mac_is_filtered $WIFIMAC && continue

	[ $(( SERVER_UNIXTIME - UNIXTIME )) -gt 10000 ] && continue		# older than 3 hours?

	log "wifimode: $WIFIMODE"

	print()
	{
		echo "$NODE $HOSTNAME"
		log "map.temp.node2hostname: $NODE $HOSTNAME"
	}

	case "$WIFIMODE" in
		adhoc*|mac80211|ath9k-mac80211)
			print
		;;
	esac

	case "$HOSTNAME" in
		KG-maschinenraum-AP)
			print
		;;
	esac

} done >map.temp.node2hostname

for FILE in $FILELIST; do {						# describe each node (shape, label, color ...)
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

echo

[ -e ./map.temp.conns ] && rm ./map.temp.conns

for FILE in $FILELIST; do {		# describe all connections, which are used for inet ("path to gateway")
	NEIGH=
	. $FILE

#	log "neigh: $NEIGH"

	echo "$NEIGH" | while read -r LINE; do {

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

echo

for FILE in $FILELIST; do {		# describe all connections, which are not used for inet, and are not described before
	. $FILE

	echo $NEIGH | sed 's/[=~-]/\n&/g' | while read -r LINE; do {
		[ -z "$LINE" ] && continue

		NDEV="$(   func_interpret_neigh ndev   $LINE )"
		NNEIGH="$( func_interpret_neigh nneigh $LINE )"
		NCOST="$(  func_interpret_neigh ncost  $LINE )"
		LOCAL="$(  func_nodenumber2hostname $NODE )"
		REMOTE="$( func_nodenumber2hostname $NNEIGH )"
		COST="$( echo $NCOST | sed 's/[^0-9]//g' )"

		if [ -z "$LOCAL" ] || [ -z "$REMOTE" ]; then continue; fi

		[ -z "$COST"     ] && continue
		[ $COST -gt 5000 ] && continue		# only good neighs for smaller topo

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

		grep -q ^"$LOCAL $REMOTE" ./map.temp.conns 2>/dev/null && continue

		echo "	\"$LOCAL\" -> \"$REMOTE\" [ arrowhead=\"none\", arrowtail=\"none\", style=$STYLE $LABEL];"
		
		echo "$LOCAL $REMOTE" >>map.temp.conns
		echo "$REMOTE $LOCAL" >>map.temp.conns
	} done
} done

echo "}"

rm 2>/dev/null ./map.temp.node2hostname ./map.temp.conns

