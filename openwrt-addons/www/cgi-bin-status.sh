#!/bin/sh
. /tmp/loader

_http header_mimetype_output 'text/html'

output_table()
{
	local file='/tmp/OLSR/LINKS.sh'
	local line word remote_hostname iface_out mac snr bgcolor toggle
	local LOCAL REMOTE LQ NLQ COST COUNT=0 cost_int cost_color snr_color
	local head_list='Nachbar-IP Hostname Schnittstelle Lokale_Interface-IP LQ NLQ ETX SNR'
	local gateway="$( _sanitizer do "$( ip route list exact '0.0.0.0/0' table main )" ip4 )"

	for word in $head_list; do {
		echo -n "<th> $word &nbsp;&nbsp;&nbsp;&nbsp;</th>"
	} done

	# todo:
	# - legende
	# - gateway: bg=yellow
	# - neigh: $REMOTE_HOSTNAME, $IFACE_OUT, $SNR
	# - link/href first 2 params
	# - colors ETX + SNR

	_net include
	while read line; do {
		# LOCAL=10.63.2.3;REMOTE=10.63.48.65;LQ=0.796;NLQ=0.000;COST=;COUNT=$(( $COUNT + 1 ))
		eval $line
		remote_hostname="$( _net ip2dns "$REMOTE" )"
		iface_out="$( _net ip2dev "$REMOTE" )"

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

		if _net dev_is_wifi "$iface_out"; then
			if mac="$( _net ip2mac "$REMOTE" )"; then
				snr="$( iw dev "$iface_out" station get "$mac" | fgrep 'signal avg:' )"

				if [ -n "$snr" ]; then
					set -- $snr
					snr="$(( 95 + $3 ))"	# 95 = noise_base

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
					snr='error'
					snr_color='red'
				fi
			else
				snr='error'
				snr_color='red'
			fi
		else
			# use net_dev_type()
			snr='ethernet'
			snr_color='green'
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
 <td> $iface_out </td>
 <td> $LOCAL </td>
 <td> $LQ </td>
 <td> $NLQ </td>
 <td bgcolor='$cost_color'> $COST </td>
 <td bgcolor='$snr_color'> $snr </td>
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
  <h1>$HOSTNAME</h1>
  <h3><a href='#'> OLSR-Verbindungen </a></h3>
  <big>&Uuml;bersicht &uuml;ber aktuell bestehende OLSR-Verbindungen</big><br>

  <table cellspacing='5' cellpadding='5' border='0'>
EOF

output_table

cat <<EOF
  </table>

  <h3>Legende:</h3>
  <ul>
   <li> <b>LQ</b>: Erfolgsquote vom Nachbarn empfangener Pakete </li>
   <li> <b>NLQ</b>: Erfolgsquote zum Nachbarn gesendeter Pakete </li>
   <li> <b>ETX</b>: Zu erwartende Sendeversuche pro Paket </li>
   <ul>
    <li> <b><font color='green'>Gr&uuml;n</font></b>: Sehr gut (ETX < 2) </li>
    <li> <b><font color='yellow'>Gelb</font></b>: Gut (2 < ETX < 4) </li>
    <li> <b><font color='orange'>Orange</font></b>: Noch nutzbar (4 < ETX < 10) </li>
    <li> <b><font color='red'>Rot</font></b>: Schlecht (ETX > 10) </li>
   </ul>
   <li> <b>SNR</b>: Signal Noise Ratio in dB </li>
   <ul>
    <li> <b><font color='green'>Gr&uuml;n</font></b>: Very good (SNR > 30) </li>
    <li> <b><font color='yellow'>Gelb</font></b>: Good (30 > SNR > 20) </li>
    <li> <b><font color='orange'>Orange</font></b>: Still usable (20 > SNR > 5) </li>
    <li> <b><font color='red'>Rot</font></b>: Bad (SNR < 5) </li>
   </ul>
  </ul>

 <body>
</html>
EOF
