#!/bin/sh
. /tmp/loader

[ -n "$REMOTE_ADDR" ] && {
	show_pregenerated()
	{
		[ -e '/tmp/statuspage_neigh_pregenerated' ] || return 1

		# no cpu-cycles for crawlers
		_net ip4_is_private "$REMOTE_ADDR" || return 0

		if [ -e "/tmp/statuspage_neigh_lastfetch_$REMOTE_ADDR" ]; then
			if _file age "/tmp/statuspage_neigh_lastfetch_$REMOTE_ADDR" -gt 600 ; then
				return 0
			else
				return 1
			fi
		else
			return 0
		fi
	}

	if show_pregenerated ; then
		touch "/tmp/statuspage_neigh_lastfetch_$REMOTE_ADDR"

		case "$HTTP_ACCEPT_ENCODING" in
			# https://en.wikipedia.org/wiki/HTTP_compression#Content-coding_tokens
			# try uhttpd patch: https://lists.openwrt.org/pipermail/openwrt-devel/2015-October/036280.html
			*'gzip'*)
				_http header_mimetype_output 'text/html' 'gzip'

				if [ -e '/tmp/statuspage_neigh_pregenerated.gz' ]; then
					cat '/tmp/statuspage_neigh_pregenerated.gz'
				else
					gzip -f -c '/tmp/statuspage_neigh_pregenerated'
				fi
			;;
			*)
				_http header_mimetype_output 'text/html'
				cat '/tmp/statuspage_neigh_pregenerated'
			;;
		esac

		exit 0
	else
		_http header_mimetype_output 'text/html'
	fi
}

remote_hops()
{
	local remote_nodenumber remote_lanadr

	remote_nodenumber="$( _ipsystem get "$REMOTE_ADDR" )"
	remote_lanadr="$( _ipsystem getvar 'LANADR' $remote_nodenumber )"

	_olsr remoteip2metric "$remote_lanadr" || echo '?'
}

output_table()
{
	local funcname='output_table'
	local file='/tmp/OLSR/LINKS.sh'
	local line word remote_hostname iface_out iface_out_color mac snr bgcolor toggle rx_mbytes tx_mbytes all gw_file report
	local LOCAL REMOTE LQ NLQ COST COUNT=0 cost_int cost_color snr_color dev channel metric gateway gateway_percent vpn_proto
	local head_list neigh_list neigh_file neigh age inet_offer cost_best cost_best_time th_insert mult_ip count cost_align i
#	local noisefloor
	local symbol_infinite='<big>&infin;</big>' metric_ok='false'
	local mult_list="$( uci -q get olsrd.@Interface[0].LinkQualityMult ) $( uci -q get olsrd.@Interface[1].LinkQualityMult )"
	export MINSTREL_MAC MINSTREL_DEV MINSTREL_NEEDED=0

	if [ -e '/tmp/OLSR/DEFGW_NOW' ]; then
		read -r gateway <'/tmp/OLSR/DEFGW_NOW'
		[ "$gateway" = 'empty' ] && gateway=
	else
		gateway=
	fi

	all=0
	for gw_file in /tmp/OLSR/DEFGW_[0-9]*; do {
		[ -e "$gw_file" ] && {
			read -r i <"$gw_file"
			all=$(( all + i ))
		}
	} done

	for neigh_file in /tmp/OLSR/isneigh_*; do {
		case "$neigh_file" in
			*'_bestcost')
			;;
			*)
				[ -e "$neigh_file" ] && {
					neigh_list="$neigh_list ${neigh_file#*_}"
				}
			;;
		esac
	} done

	# tablehead - change also 'colspan' in 'old neighs' when we add/del something here
	printf '<tr>'
	head_list='No. Nachbar-IP Hostname Schnittstelle lokale&nbsp;Interface-IP'
	head_list="$head_list LQ NLQ ETX ETX<small><sub>min</sub></small>"
	head_list="$head_list Speed<small><sub>best</sub></small> SNR Metrik raus rein Gateway"
	for word in $head_list; do {
		case "$word" in
			'Gateway')
				if [ -e '/tmp/OLSR/DEFGW_empty' ]; then
					read -r i <'/tmp/OLSR/DEFGW_empty'
					[ $all -gt 0 ] && {
						divisor_valid "$all" || all=1
						word="$word ($(( (i * 100) / all ))% Inselbetrieb)"	# divisor_valid
					}
				elif inet_offer="$( _net local_inet_offer cached )"; then
					word="$word (Einspeiser: $inet_offer)"

					bool_true 'system.@monitoring[0].report_wantraffic' && report='true'
					[ "$inet_offer" = 'wwan' ] && report='true'

					[ "$report" = 'true' ] && {
						_log it $funcname daemon alert "traffic: $( _net get_rxtx "$WANDEV" )"
					}
				fi

				[ -z "$gateway" ] && th_insert=" bgcolor='crimson'"
			;;
			'ETX')
				th_insert='class="sorttable_numeric"'
			;;
		esac

		printf '%s' "<th valign='top' nowrap ${th_insert}>$word</th>"
	} done
	printf '%s' '</tr>'

	local octet3
	get_octet3()
	{
		local ip="$1"

		ip=${ip#*.}
		ip=${ip#*.}
		octet3=${ip%.*}
	}

	build_cost_best()
	{
		local remote_ip="$1"
		local cost_file="/tmp/OLSR/isneigh_${remote_ip}_bestcost"

		if [ -e "$cost_file" ]; then
			cost_best_time="$( _file time "$cost_file" humanreadable )"
			read -r cost_best <"$cost_file"
		else
			cost_best='&mdash;'
		fi
	}

	build_remote_hostname()		# sets var '$remote_hostname'
	{
		local remote_ip="$1"
		local cachefile="$TMPDIR/build_remote_hostname_$remote_ip"
		local url="http://$remote_ip/cgi-bin-tool.sh?OPT=hostname"

		if [ -e "$cachefile" ]; then
			read -r remote_hostname <"$cachefile"
			return 0
		else
			remote_hostname="$( _net ip2dns "$remote_ip" )" || {
				_watch counter "$cachefile.try" increment 1 max 5 && {
					remote_hostname="$( _curl it "$url" )"
				}
			}
		fi

		# did not work (e.g. via nameservice-plugin), so ask the remote directly
		[ -z "$remote_hostname" -o "$remote_hostname" = "$remote_ip" ] && {
			# nameservice-plugin needs some time
			if [ $( _olsr uptime ) -lt 400 ]; then
				remote_hostname="$( _tool remote "$remote_ip" hostname )"
			else
				remote_hostname=
			fi

			if [ -z "$remote_hostname" ]; then
				remote_hostname="$remote_ip"
			else
				# otherwise we could include a redirect/404
				remote_hostname="$( _sanitizer run "$remote_hostname" strip_newlines hostname )"
			fi
		}

		case "$remote_hostname" in
			mid[0-9].*|mid[0-9][0-9].*)
				remote_hostname="${remote_hostname#*.}"	# mid3.F36-Dach4900er-MESH -> F36-Dach4900er-MESH
			;;
			'DOCTYPEhtml'*|'xmlversion'*|'htmlxml'*)	# fetched 404/error-page
				case "$remote_hostname" in
					*'title'*)
						remote_hostname="$( echo "$remote_hostname" | sed 's/^.*title\(.*\)title.*/\1/' )"
					;;
					*)
						remote_hostname="$remote_ip"
					;;
				esac
			;;
		esac

		case "$remote_hostname" in
			"$remote_ip"|'mywifi'*|'user-lan'*|'ERROR')	# see S43ethers and net_ip2dns()
			;;
			*'.'*)
				remote_hostname="${remote_hostname%.*}"		# myhost.lan -> myhost
				echo "$remote_hostname" >"$cachefile"
			;;
			*)
				echo "$remote_hostname" >"$cachefile"
			;;
		esac
	}

	_net include
	_olsr include
	count=0
	export COUNT		# shellcheck SC2034
	while read -r line; do {
		# LOCAL=10.63.2.3;REMOTE=10.63.48.65;LQ=0.796;NLQ=0.000;COST=1.875;COUNT=$(( COUNT + 1 ))
		eval $line

		count=$(( count + 1 ))
		case "$LOCAL" in
			"$WIFIADR")
				iface_out="$WIFIDEV"
			;;
			"$LANADR")
				iface_out="$LANDEV"
			;;
			"$WANADR")
				iface_out="$WANDEV"
			;;
			*)
				iface_out="$( _net ip2dev "$REMOTE" )"
			;;
		esac
		neigh_list="$( _list remove_element "$neigh_list" "$REMOTE" 'string' )"

		# TODO: do not try hard if bad/lost neigh
		build_remote_hostname "$REMOTE"

		case "$toggle" in
			'even')
				toggle=
				bgcolor=
			;;
			*)
				toggle='even'
				bgcolor='beige'
			;;
		esac

		if [ -e "/tmp/OLSR/DEFGW_$REMOTE" ]; then
			read -r i <"/tmp/OLSR/DEFGW_$REMOTE"
			[ $all -gt 0 ] && {
				divisor_valid "$all" || all=1
				gateway_percent=$(( (i * 100) / all ))	# divisor_valid
			}
			gateway_percent="${gateway_percent}%"		# TODO: sometimes >100%

			METRIC=
			ETX=
#			GATEWAY=
#			INTERFACE=
			[ -e "/tmp/OLSR/DEFGW_VALUES_$REMOTE" ] && . "/tmp/OLSR/DEFGW_VALUES_$REMOTE"
		else
			gateway_percent=
		fi

		if [ "$gateway" = "$REMOTE" ]; then
			bgcolor='#ffff99'				# lightyellow

			if [ -n "$METRIC" ]; then
				gateway_percent="${gateway_percent:-100%}, $METRIC Hops, ETX $ETX"
			else
				gateway_percent="(kein HNA!)"
			fi
		else
			[ -n "$gateway_percent" ] && {
				gateway_percent="$( _file age "/tmp/OLSR/DEFGW_$REMOTE" humanreadable )"
				gateway_percent="$gateway_percent (vor $gateway_percent, ETX: $ETX)"
			}
		fi

		metric="$( _olsr remoteip2metric "$REMOTE" )"
		case "$metric" in
			'1')
				metric='direkt'
				metric_ok='true'	# we need at least 1 direct neigh, otherwise we restart the daemon later
			;;
			'')
				metric='&mdash;'
			;;
		esac

		is_wifi()
		{
			local dev="$1"

			_net dev_is_wifi "$dev" && return 0
			[ "$LOCAL" = "$WIFIADR" ] && return 0	# TODO: will not work for 2nd wifi

			case "$dev" in
				$LANDEV|$WANDEV)
					return 1
				;;
			esac

			case "$COST" in
				'1.000'|'0.100')
					return 1
				;;
				*)
					# likely no ethernet/VPN
					_net dev_is_tuntap "$dev" || return 0
				;;
			esac

			return 1
		}

		channel=; snr=; rx_mbytes=; tx_mbytes=
		if is_wifi "$iface_out"; then
			iface_out_color=

			if mac="$( _net ip2mac "$REMOTE" lazy )"; then
				for dev in $WIFI_DEVS; do {

					# maybe use: wifi_get_station_param / wifi_show_station_traffic
					explode $( iw dev "$dev" station get "$mac" 2>/dev/null )
					while [ -n "$1" ]; do {
						shift

						case "$1 $2" in
							'signal avg:')
								MINSTREL_NEEDED=$(( MINSTREL_NEEDED + 1 ))
								MINSTREL_MAC="$mac"
								MINSTREL_DEV="$dev"

								snr="$3"
								break 2
							;;
							'rx bytes:')
								rx_mbytes=$(( $3 / 1024 / 1024 ))
								[ $rx_mbytes -eq 0 ] && rx_mbytes='&mdash;'
							;;
							'tx bytes:')
								tx_mbytes=$(( $3 / 1024 / 1024 ))
								[ $tx_mbytes -eq 0 ] && tx_mbytes='&mdash;'
							;;
						esac
					} done
				} done

				if [ -n "$snr" ]; then
					channel="$( _wifi channel "$dev" )"
					[ $channel -ge 36 ] && iface_out_color='YellowGreen'
					channel="/Kanal&nbsp;$channel"

					# 95 = noise_base / drivers_default
					#
					# http://en.wikipedia.org/wiki/Thermal_noise#Noise_power_in_decibels
					# https://lists.open-mesh.org/pipermail/b.a.t.m.a.n/2014-April/011911.html
					# http://comments.gmane.org/gmane.linux.drivers.ath9k.devel/6100
					#
					# root@box:~ cat /sys/kernel/debug/ieee80211/phy0/ath9k/dump_nfcal
					# Channel Noise Floor : -95
					# Chain | privNF | # Readings | NF Readings
					#  0	 -117	 5		 -116 -117 -117 -117 -117
					#  3	 -117	 5		 -116 -117 -116 -117 -117
					#
					# root@TP1043-2.4GHz:~ cat /sys/kernel/debug/ieee80211/phy0/ath9k/dump_nfcal
					# Channel Noise Floor : -95
					# Chain | privNF | # Readings | NF Readings
					#  0	 -93	 5		 -92 -93 -93 -93 -91
					#  1	 -89	 5		 -89 -89 -89 -89 -88
					#  2	 -85	 5		 -85 -85 -85 -85 -85
					#
					# see on b43: snr=-98

#					if [ -z "$noisefloor" -a -e "/sys/kernel/debug/ieee80211/phy0/ath9k/dump_nfcal" ]; then
#						:
#					else
#						noisefloor=95
#					fi

					snr=$(( 95 + snr ))

					# TODO: auto-adjust noise_base for this dev/channel
					[ $snr -lt 0 ] && snr=0

					# TODO: 5ghz needs other margins (e.g. 13 gives e.g. 1MByte/s)
					if   [ $snr -gt 30 ]; then
						snr_color='green'
					elif [ $snr -gt 20 ]; then
						snr_color='yellow'
					elif [ $snr -gt 5  ]; then
						snr_color='orange'
					else
						snr_color='red'
					fi
				else
					snr='error/no_assoc'
					snr_color='red'
				fi
			else
				snr='error/no_mac'
				snr_color='red'
			fi
		else
			# use net_dev_type()
			snr='ethernet'
			snr_color='green'
			iface_out_color='green'

			case "$iface_out" in
				$LANDEV)
					channel='/LAN'
				;;
				$WANDEV)
					channel='/WAN'
				;;
				*)
					_net dev_is_tuntap "$iface_out" && {
						# FIXME! this means we have to set it on client too (works and is ignored by the parser)
						[ -z "$vpn_proto" ] && vpn_proto="$( grep -Fq -m1 'proto udp' "$TMPDIR/vtund.conf" && echo 'udp' )"
						channel="/${vpn_proto:=tcp}VPN"

						snr='vpn'
						snr_color='SpringGreen'
						iface_out_color='SpringGreen'
					}
				;;
			esac

			bytes_rx=;bytes_tx=
			eval $( _net get_rxtx "$iface_out" )	# bytes_rx | bytes_tx

			rx_mbytes=$(( bytes_rx / 1024 / 1024 ))
			[ $rx_mbytes -eq 0 ] && rx_mbytes='&mdash;'
			tx_mbytes=$(( bytes_tx / 1024 / 1024 ))
			[ $tx_mbytes -eq 0 ] && tx_mbytes='&mdash;'
		fi

		# TODO: detect proper $REMOTE - type, $LOCAL is wrong
		case "x$LOCAL" in
			$LANADR|$WANADR)
				snr='ethernet'
				snr_color='green'
				iface_out_color='green'

				case "$LOCAL" in
					$LANADR)
						channel='/LAN_bla'
					;;
					$WANADR)
						channel='/WAN_bla'
					;;
				esac
			;;
		esac

		cost_int="${COST%.*}${COST#*.}"
		if   [ -z "$cost_int" ]; then
			cost_int=99999		# for sorting - TODO: does not work
			cost_color='red'
		elif [ $cost_int -gt 10000 ]; then
			cost_color='red'
		elif [ $cost_int -gt 4000  ]; then
			cost_color='orange'
		elif [ $cost_int -gt 2000  ]; then
			cost_color='yellow'
		else
			cost_color='green'
		fi

		case " $mult_list " in
			*" $REMOTE "*)
				# e.g. '10.10.12.1 0.7 10.10.99.1 0.3' -> 0.7
				mult_ip="${mult_list#*$REMOTE }"
				mult_ip="${mult_ip%% *}"
			;;
			*)
				mult_ip=
			;;
		esac

		if [ -n "$COST" ]; then
			cost_align='right'
			[ -n "$mult_ip" ] && COST="${mult_ip}&nbsp;&lowast;&nbsp;${COST}"
		else
			cost_align='center'
			COST="$symbol_infinite"
			[ -n "$mult_ip" ] && COST="(${mult_ip}&nbsp;&lowast;)&nbsp;$COST"
		fi

		build_cost_best "$REMOTE"
		get_octet3 "$REMOTE"

		cat <<EOF
<tr bgcolor='$bgcolor'>
 <td align='right'><small>$count</small></td>
 <td nowrap sorttable_customkey='$octet3'> <a href='http://$REMOTE/cgi-bin-status.html'>$REMOTE</a> </td>
 <td nowrap> <a href='http://$REMOTE/cgi-bin-status.html'>$remote_hostname</a> </td>
 <td bgcolor='$iface_out_color'> ${iface_out}${channel} </td>
 <td> $LOCAL </td>
 <td> $LQ </td>
 <td> $NLQ </td>
 <td sorttable_customkey='$cost_int' align='$cost_align' bgcolor='$cost_color'> $COST </td>
 <td align='right' title='$cost_best_time'> $cost_best </td>
 <td align='right'>$( _wifi speed cached $REMOTE | cut -d'-' -f2 )</td>
 <td align='right' bgcolor='$snr_color'> $snr </td>
 <td align='center' $( test "$metric" = '&mdash;' && echo "bgcolor='crimson'" )> $metric </td>
 <td align='right'> $rx_mbytes </td>
 <td align='right'> $tx_mbytes </td>
 <td nowrap> $gateway_percent </td>
</tr>
EOF
	} done <"$file"

	# old neighs, which are unknown now
	for neigh in $neigh_list; do {
		get_octet3 "$neigh"
		age="$( _file age "/tmp/OLSR/isneigh_$neigh" humanreadable_verbose )"
		build_remote_hostname "$neigh"
		build_cost_best "$neigh"
		count=$(( count + 1 ))
		metric="$( _olsr remoteip2metric "$neigh" )"

		echo "<tr>"
		echo " <td align='right'><small>$count</small></td>"
		echo " <td sorttable_customkey='$octet3'> <a href='http://$neigh/cgi-bin-status.html'>$neigh</a> </td>"
		echo " <td> <a href='http://$neigh/cgi-bin-status.html'>$remote_hostname</a> </td>"
		echo " <td colspan='5' nowrap align='right'> vermisst seit $age </td>"
		echo " <td align='right' title='$cost_best_time'> $cost_best </td>"
		echo " <td>&nbsp;</td>"		# speed
		echo " <td>&nbsp;</td>"		# SNR
		echo " <td align='center'> ${metric:-&mdash;} </td>"
		echo " <td colspan='3'> &nbsp; </td>"
		echo "</tr>"
	} done

	test "$metric_ok" = 'true'
}

[ -e '/tmp/OLSR/ALL' ] || _olsr build_tables

# in /tmp/OLSR/ALL
# Table: Links
# Table: Neighbors
# Table: Topology
# Table: HNA
# Table: MID
# Table: Routes

# TODO: 'Table: HNA' -> $1 = 0.0.0.0/0 = Einspeiser

# count all uniq entries/destinations in table 'Topology'
NODE_COUNT=0
NODE_LIST=
PARSE=
while read -r LINE; do {
	case "${PARSE}${LINE}" in
		'Table: Topology')
			PARSE='true-'
		;;
		'true-Dest. IP'*)
		;;
		'true-')
			NODE_LIST=
			break
		;;
		'true-'*)
			# 10.63.1.97  10.63.183.33  0.121  0.784  10.487
			explode $LINE
			case "$NODE_LIST" in
				*" $1 "*)
					# already in list
				;;
				*)
					NODE_LIST="$NODE_LIST $1 "
					NODE_COUNT=$(( NODE_COUNT + 1 ))
				;;
			esac
		;;
	esac
} done <'/tmp/OLSR/ALL'

read -r ROUTE_COUNT <'/tmp/OLSR/ROUTE_COUNT'

if [ -e '/tmp/OLSR/ALL' ]; then
	AGE_DATABASE="$( _file age '/tmp/OLSR/ALL' sec )"
else
	if _olsr uptime is_short; then
		AGE_DATABASE=-1
	else
		if _olsr build_tables; then
			AGE_DATABASE="$( _file age '/tmp/OLSR/ALL' sec )"
		else
			AGE_DATABASE="$( _system uptime sec )"
		fi
	fi
fi

if   [ $AGE_DATABASE -gt 120 ]; then
	echo >>$SCHEDULER_IMPORTANT "_olsr build_tables"
	AGE_HUMANREADABLE="&nbsp;&nbsp; Achtung: Datengrundlage >$( _stopwatch seconds2humanreadable "$AGE_DATABASE" ) alt"
elif [ $AGE_DATABASE -eq -1 ]; then
	AGE_HUMANREADABLE="&nbsp;&nbsp; Achtung: OLSR-Dienst gerade erst gestartet, keine Daten vorhanden"
fi

BOOTTIME=$(( $( date +%s ) - $( _system uptime sec ) ))
BOOTTIME="$( _system date unixtime2date "$BOOTTIME" )"		# Thu Nov 27 04:10:39 CET 2014

# TODO: move to unixtime2date() ???
case "$BOOTTIME" in
	# Thu Nov 27
	"$( date "+%a %b %e" ) "*)
		explode $BOOTTIME
		shift 3
		BOOTTIME="seit heute $1 Uhr"
	;;
	*)
		BOOTTIME="seit $BOOTTIME"
	;;
esac


# changes/min
if [ -e '/tmp/OLSR/DEFGW_changed' ]; then
	UP_MIN=$( _system uptime min )

	GATEWAY_JITTER=0
	while read -r LINE; do {
		explode $LINE
		# do not take empty gw into account, only real changes
		[ -n "$3" -a "$3" != "$GW_OLD" ] && {
			GW_OLD="$3"
			GATEWAY_JITTER=$(( GATEWAY_JITTER + 1 ))
		}
	} done <'/tmp/OLSR/DEFGW_changed'

	if [ $GATEWAY_JITTER -le 1 ]; then
		GATEWAY_JITTER='nie'
	else
		divisor_valid "$GATEWAY_JITTER" || GATEWAY_JITTER=1
		GATEWAY_JITTER="$GATEWAY_JITTER &Oslash; alle $(( UP_MIN / GATEWAY_JITTER )) min"	# divisor_valid
	fi
else
	GATEWAY_JITTER='nie'
fi

cat <<EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html>
 <head>
  <title>$HOSTNAME - No. $NODENUMBER - Nachbarn @$( _system date humanreadable pretty )</title>
  <META HTTP-EQUIV="content-type" CONTENT="text/html; charset=ISO-8859-15">
EOF

_http include_js_sorttable

rrd_info()
{
	# TODO: embedd into page

	if _rrd needed; then
		printf '%s' '<a href="traffic.png">RRD</a>'
	else
		printf '%s' 'no_RRD'
	fi
}

cat <<EOF
 </head>
 <body>
  <h1>host '$HOSTNAME' &ndash; No. ${NODENUMBER:-unset} (mit $( _system version_string ) auf '$HARDWARE')</h1>
  <big><a href='netjson.html'> OLSRv1-Verbindungen </a> ${AGE_HUMANREADABLE}&emsp;</big>
   <small>Version: $( _olsr version ) | system <b>uptime</b>: $( _system uptime humanreadable ) ($BOOTTIME) | kalua age: $( _file age '/etc/variables_fff+' humanreadable ) ($( _firmware updatemode )) | $( _system cpucount ) CPU-Kerne | $( rrd_info )</small><br><br>
  <big>&Uuml;bersicht &uuml;ber aktuell bestehende OLSR-Verbindungen ($NODE_COUNT Netzknoten, $ROUTE_COUNT Routen, $( remote_hops ) Hops zu Betrachter $REMOTE_ADDR, Gatewaywechsel: $GATEWAY_JITTER)</big><br>

  <table cellspacing='5' cellpadding='5' border='0' class='sortable'>
EOF

output_table "$@" || {		# SC2119/SC2120
	_log it watch_metric daemon alert 'killing daemon, let cron restart it'
	killall olsrd
}

echo '  </table>'
_switch show 'html' 'Ansicht der Netzwerkanschl&uuml;sse:&nbsp;'

[ "$MINSTREL_NEEDED" = '1' ] && {
	echo '<pre>'
	echo "wifi rate sampling / minstrel-Tabelle f&uuml;r station $MINSTREL_MAC@$MINSTREL_DEV"
	echo
	_wifi minstrel "$MINSTREL_MAC" debug
	echo '</pre>'
}

bool_true 'system.@monitoring[0].cisco_collect' && {
	_cisco collect show
}

cat <<EOF
  <h3> Legende: </h3>
  <ul>
   <li> <b>Metrik</b>: Daten werden direkt oder &uuml;ber Zwischenstationen gesendet </li>
   <li> <b>Raus</b>: Tx = gesendete Daten = Upload [Megabytes] </li>
   <li> <b>Rein</b>: Rx = empfangene Daten = Download [Megabytes] </li>
   <li> <b>LQ</b>: Erfolgsquote vom Nachbarn empfangener Pakete </li>
   <li> <b>NLQ</b>: Erfolgsquote zum Nachbarn gesendeter Pakete </li>
   <li> <b>ETX</b>: zu erwartende Sendeversuche pro Paket (k&uuml;nstlicher Multiplikator wird angezeigt)</li>
   <li>
   <ul>
    <li> <b><font color='green'>Gr&uuml;n</font></b>: sehr gut (ETX < 2) </li>
    <li> <b><font color='yellow'>Gelb</font></b>: gut (2 < ETX < 4) </li>
    <li> <b><font color='orange'>Orange</font></b>: noch nutzbar (4 < ETX < 10) </li>
    <li> <b><font color='red'>Rot</font></b>: schlecht (ETX > 10) </li>
   </ul>
   </li>
   <li> <b>SNR</b>: Signal/Noise-Ratio = Signal/Rausch-Abstand [dB] </li>
   <li>
   <ul>
    <li> <b><font color='green'>Gr&uuml;n</font></b>: sehr gut (SNR > 30) </li>
    <li> <b><font color='yellow'>Gelb</font></b>: gut (30 > SNR > 20) </li>
    <li> <b><font color='orange'>Orange</font></b>: noch nutzbar (20 > SNR > 5) </li>
    <li> <b><font color='red'>Rot</font></b>: schlecht (SNR < 5) </li>
   </ul>
   </li>
  </ul>

  <pre>$( test $OPENWRT_REV -eq -1 && ps ax )</pre>
 </body>
</html>
EOF
