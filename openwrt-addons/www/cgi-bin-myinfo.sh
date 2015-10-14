#!/bin/sh
. /tmp/loader

_log it myinfo daemon info "[OK] fetched from $REMOTE_ADDR"
_http header_mimetype_output text/html
echo "<html><head><title>myinfo :: $HOSTNAME :: $CONFIG_PROFILE</title></head><body>"

MAC="$( _net ip2mac "$REMOTE_ADDR" )" && {
	_netfilter user_probe "$MAC" && {
		_netfilter user_list verbose "$MAC" | while read -r LINE; do {
			case "$LINE" in
				"#"*)
				;;
				*":"*)
					set -- $LINE

					echo "<h3>Nutzerdaten</h3><pre>"
					echo "IP-Adresse: $REMOTE_ADDR"
					echo "MAC-Adresse: $MAC"
					echo "Verbindungstyp: $5"
					echo "verursachter Datenverkehr heute: $7"
					echo "initiale Geschwindigkeit: runterladen/hochladen: $9 [Kilobit/Sekunde]"
					echo "Nexthop: $( cat /tmp/OLSR/DEFGW_NOW ) - $( _wifi speed )"

					case "${11}" in
						*"%"*)
							echo "Drosselung auf ${11} -> ${13} [Kilobit/Sekunde]"
							shift 15
						;;
						*)
							echo "ungedrosselte Geschwindigkeit"
							shift 11
						;;
					esac

					echo "Hersteller: $*"
					echo "WLAN-Empfang:"

					# TODO: get real interface
					iw dev 'wlan0'   station get "$MAC" | grep "signal\|bitrate:"
					iw dev 'wlan0-1' station get "$MAC" | grep "signal\|bitrate:"
					_wifi minstrel "$MAC" debug

					echo "</pre>"
				;;
			esac
		} done
	}
}


if [ -e '/tmp/BATCTL_TRACEROUTE' ]; then
	GATEWAY="$( uci get network.mybridge.gateway )"

	echo "<h3>Routenverfolgung zum Zentralgeraet '$GATEWAY' vor $( _file age '/tmp/BATCTL_TRACEROUTE' sec ) sec</h3>"
	echo '<pre'
	cat '/tmp/BATCTL_TRACEROUTE'
	echo '</pre>'
	echo "<h3>Routenverfolgung zum Zentralgeraet jetzt:</h3>"
	echo '<pre>'
	batctl traceroute "$GATEWAY"
	echo '</pre>'
else
	read -r GATEWAY </tmp/GATEWAY_CHECK_RECENT_GATEWAY_IP_ONLY

	echo "<h3>Routenverfolgung zum Gateway '$GATEWAY' zum Zeitpunkt $( _system date humanreadable pretty )</h3>"
	echo "<pre>$( traceroute $GATEWAY )</pre>"
fi

echo "<h3>Testdownload einer 5 Megabyte-Datei</h3>"
echo "<small><b>Hinweis</b>: Sie k&ouml;nnen manuell einen Geschwindkeitstest durchf&uuml;hren, indem Sie folgende Dateien herunterladen und die Zeit stoppen den dieser Vorgangs ben&ouml;nigt. Dauert es z.b. 50 Sekunden, errechnet sich die resultierende Geschwindigkeit nach diesem Schema: 80 Mbit / 50 Sekunden = 1,6 Megabit/Sekunde.</small>"

echo "<p>"
echo "<a href='http://$LANADR/cgi-bin-tool.sh?OPT=download'>Testdownload Server1</a>&nbsp;(IP: $LANADR = '$HOSTNAME')<br>"
echo "<small><pre>"
ping -c3 $LANADR
echo "</pre></small>"
echo "<a href='http://$GATEWAY/cgi-bin-tool.sh?OPT=download'>Testdownload Server2</a>&nbsp;(IP: $GATEWAY)<br>"
echo "<small><pre>"
ping -c3 $GATEWAY
echo "</pre></small>"

AUTHSERVER="$( _weblogin authserver )"
[ "$AUTHSERVER" = "$GATEWAY" ] || {
	echo "<a href='http://$AUTHSERVER/cgi-bin-tool.sh?OPT=download'>Testdownload Server3</a>&nbsp;(IP: $AUTHSERVER)"
	echo "<small><pre>"
	ping -c3 $AUTHSERVER
	echo "</pre></small>"
}



echo "</p></body></html>"
