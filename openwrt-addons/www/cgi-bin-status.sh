#!/bin/sh
. /tmp/loader

_http header_mimetype_output 'text/html'

output_table()
{
	local file='/tmp/OLSR/LINKS.sh'
	local line word remote_hostname iface_out iface_out_color mac snr bgcolor toggle rx_mbytes tx_mbytes
	local LOCAL REMOTE LQ NLQ COST COUNT=0 cost_int cost_color snr_color dev channel metric
	local head_list='Nachbar-IP Hostname Schnittstelle Lokale_Interface-IP LQ NLQ ETX SNR Metrik Out In'
	local gateway="$( _sanitizer do "$( ip route list exact '0.0.0.0/0' table main )" ip4 )"
	local symbol_infinite='<big>&infin;</big>'

	for word in $head_list; do {
		echo -n "<th> $word &nbsp;&nbsp;&nbsp;&nbsp;</th>"
	} done

	# todo:
	# - wenn wlan, dann probieren ueber welche 'iw dev wlanX' die mac erreichbar ist, dann stimmt auch SNR
	# - channel mit anzeigen bzw. band (a/g)
	# - schnittstelle = lan/wire? -> gruen

	_net include
	_olsr include
	while read line; do {
		# LOCAL=10.63.2.3;REMOTE=10.63.48.65;LQ=0.796;NLQ=0.000;COST=;COUNT=$(( $COUNT + 1 ))
		eval $line
		iface_out="$( _net ip2dev "$REMOTE" )"

		remote_hostname="$( _net ip2dns "$REMOTE" )"
		# did not work (e.g. via nameservice-plugin), so ask the remote directly
		[ "$remote_hostname" = "$REMOTE" ] && {
			remote_hostname="$( _tool remote "$REMOTE" hostname )"
			if [ -z "$remote_hostname" ]; then
				remote_hostname="$REMOTE"
			else
				# otherwise we could include a redirect/404
				remote_hostname="$( _sanitizer do "$remote_hostname" strip_newlines hostname )"
			fi
		}
		case "$remote_hostname" in
			mid[0-9].*)
				# mid3.F36-Dach4900er-MESH -> F36-Dach4900er-MESH
				remote_hostname="${remote_hostname#*.}"
			;;
			'xmlversion'*)
				remote_hostname="$REMOTE"
			;;
		esac

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

		[ "$gateway" = "$REMOTE" ] && {
			bgcolor='#ffff99'	# lightyellow
		}

		metric="$( _olsr remoteip2metric "$REMOTE" )"
		case "$metric" in
			'1')
				metric='direkt'
			;;
			'')
				metric='&mdash;'
			;;
		esac

		channel=
		if _net dev_is_wifi "$iface_out"; then
			mac="$( _net ip2mac "$REMOTE" )" || {
				mac="$( _tool remote "$REMOTE" ip2mac )"
				mac="$( _sanitizer do "$mac" mac )"
			}

			channel=; snr=; rx_mbytes=; tx_mbytes=
			if [ -n "$mac" ]; then
				for dev in $WIFI_DEVS; do {

					# maybe use: wifi_get_station_param / wifi_show_station_traffic
					set -- $( iw dev "$dev" station get "$mac" )
					while [ -n "$1" ]; do {
						shift
						case "$1 $2" in
							'signal avg:')
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
					channel="/Kanal $channel"

					# 95 = noise_base / drivers_default
					# http://en.wikipedia.org/wiki/Thermal_noise#Noise_power_in_decibels
					# https://lists.open-mesh.org/pipermail/b.a.t.m.a.n/2014-April/011911.html
					snr="$(( 95 + $snr ))"

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

			iface_out_color=
		else
			# use net_dev_type()
			snr='ethernet'
			snr_color='green'
			iface_out_color='green'
		fi

		cost_int="${COST%.*}${COST#*.}"
		if   [ -z "$cost_int" ]; then
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

		cat <<EOF
<tr bgcolor='$bgcolor'>
 <td> <a href='http://$REMOTE/cgi-bin-status.html'>$REMOTE</a> </td>
 <td> <a href='http://$REMOTE/cgi-bin-status.html'>$remote_hostname</a> </td>
 <td bgcolor='$iface_out_color'> ${iface_out}${channel} </td>
 <td> $LOCAL </td>
 <td> $LQ </td>
 <td> $NLQ </td>
 <td bgcolor='$cost_color'> ${COST:-$symbol_infinite} </td>
 <td bgcolor='$snr_color'> $snr </td>
 <td align='middle'> $metric </td>
 <td align='right'> $rx_mbytes </td>
 <td align='right'> $tx_mbytes </td>
</tr>
EOF
	} done <"$file"
}

cat <<EOF
<html>
 <head>
  <title>$HOSTNAME - Nachbarn</title>
 </head>
 <body>
  <h1>$HOSTNAME (with OpenWrt r$( _system version short ))</h1>
  <h3><a href='#'> OLSR-Verbindungen </a></h3>
  <big>&Uuml;bersicht &uuml;ber aktuell bestehende OLSR-Verbindungen</big><br>

  <table cellspacing='5' cellpadding='5' border='0'>
EOF

output_table

cat <<EOF
  </table>

  <h3>Legende:</h3>
  <ul>
   <li> <b>Metrik</b>: Daten werden direkt oder &uuml;ber Zwischenstationen gesendet </li>
   <li> <b>Out</b>: Tx = gesendete Daten [Megabytes] </li>
   <li> <b>In</b>: Rx = empfangene Daten [Megabytes] </li>
   <li> <b>LQ</b>: Erfolgsquote vom Nachbarn empfangener Pakete </li>
   <li> <b>NLQ</b>: Erfolgsquote zum Nachbarn gesendeter Pakete </li>
   <li> <b>ETX</b>: Zu erwartende Sendeversuche pro Paket </li>
   <ul>
    <li> <b><font color='green'>Gr&uuml;n</font></b>: sehr gut (ETX < 2) </li>
    <li> <b><font color='yellow'>Gelb</font></b>: gut (2 < ETX < 4) </li>
    <li> <b><font color='orange'>Orange</font></b>: Nnch nutzbar (4 < ETX < 10) </li>
    <li> <b><font color='red'>Rot</font></b>: schlecht (ETX > 10) </li>
   </ul>
   <li> <b>SNR</b>: Signal Noise Ratio in dB </li>
   <ul>
    <li> <b><font color='green'>Gr&uuml;n</font></b>: sehr gut (SNR > 30) </li>
    <li> <b><font color='yellow'>Gelb</font></b>: gut (30 > SNR > 20) </li>
    <li> <b><font color='orange'>Orange</font></b>: noch nutzbar (20 > SNR > 5) </li>
    <li> <b><font color='red'>Rot</font></b>: schlecht (SNR < 5) </li>
   </ul>
  </ul>

 <body>
</html>
EOF
