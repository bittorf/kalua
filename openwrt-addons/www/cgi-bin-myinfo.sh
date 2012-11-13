#!/bin/sh
. /tmp/loader

_http header_mimetype_output text/html

MAC="$( _net ip2mac "$REMOTE_ADDR" )" && {
	_netfilter user_probe "$MAC" && {
		_netfilter user_list verbose "$MAC" | while read LINE; do {
			case "$LINE" in
				"#"*)
				;;
				*":"*)
					set -- $LINE

					echo "<html><head><title>myinfo :: $HOSTNAME :: $CONFIG_PROFILE</title></head><body><pre>"
					echo "IP-Adresse: $REMOTE_ADDR"
					echo "MAC-Adresse: $MAC"
					echo "Verbindungstyp: $5"
					echo "verursachter Datenverkehr heute: $7"
					echo "initiale Geschwindigkeit: runterladen/hochladen: $9 [Kilobit/Sekunde]"

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

					echo "Hersteller: $@"
					echo "</pre></body></html>"
				;;
			esac
		} done
	}
}
