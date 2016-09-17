#!/bin/sh

NETWORK="$1"
MAC="$2"		# max|michi|admin or NUMBER[0-9] (see pingkiller)
TEMPLATE="$3"		# or free_text
FEEDBACK="$4"

read -r USER <'/root/sms77_username.txt'
read -r PASS <'/root/sms77_password.txt'

read -r UP REST </proc/uptime
UP=${UP%.*}

read -r UP_OLD		</tmp/OLD_SENDSMS || UP_OLD=0
echo $(( UP + 60 ))	>/tmp/OLD_SENDSMS

DIFF=$(( UP - UP_OLD ))
[ $DIFF -lt 60 ] && {
	logger -s "[OK] must sleep for 60sec, last action ~$DIFF sec"
	sleep 60
}

case "$MAC" in
	*'/'*)
		MAC="$( echo "$MAC" | sed 's|/||g' )"
	;;
esac

log()
{
	local text="$(date): $0: $1"

	mkdir -p "/tmp/logs/sms"
	echo >>"/tmp/logs/sms/log.txt" "$text"
	logger -s "$text"
}

[ -z "$TEMPLATE" ] && {
	echo "Usage: $0 <network> <mac|admin|phonenumber> <template|selfdefined> [feedback]"
	exit 1
}

case "$TEMPLATE" in
	*" ffweimar-vhs "*)
		log "ignoring message '$TEMPLATE'"
		exit 0
	;;
esac

case "$NETWORK" in
	ffweimar-vhs)
		log "ignoring network '$NETWORK'"
		exit 0
	;;
esac

FILE="/var/www/networks/$NETWORK/meshrdf/recent/$MAC"
if [ -e "$FILE" ]; then
	. "$FILE"	# HOSTNAME

	case "$HOSTNAME" in
		"$NETWORK"*)
			if [ -z "$MAC" ]; then
				log "empty MAC"
				exit 1
			else
				read -r HOSTNAME <"/var/www/networks/$NETWORK/settings/${MAC}.hostname"
			fi
		;;
		*)
			read -r HOSTNAME_HERE <"/var/www/networks/$NETWORK/settings/${MAC}.hostname"
			[ "$HOSTNAME" = "$HOSTNAME_HERE" ] || {
				echo "which hostname to take?"
				echo "[1] $HOSTNAME"
				echo "[2] $HOSTNAME_HERE"
				read -r CHOICE
				[ "$CHOICE" = "2" ] && HOSTNAME="$HOSTNAME_HERE"
			}
		;;
	esac
else
	HEX='0-9a-fA-F'

	case "$MAC" in
		admin*)				# e.g. admin-112233445565
			[ ${#MAC} -gt 5 ] && {
				MAC="$( echo "$MAC" | cut -d'-' -f2 )"
				. "/var/www/networks/$NETWORK/meshrdf/recent/$MAC"	# NODE
				read -r HOSTNAME <"/var/www/networks/$NETWORK/settings/${MAC}.hostname"
			}

			MOBILE="0176/24223419"	# bastian
			FROM="MONITORING"	# 10 chars
		;;
		sylvia)
			MOBILE="0179/7465017"
			FROM="basti"
		;;
		franzi)
			MOBILE="0172/3701675"
			FROM="basti"
		;;
		[$HEX][$HEX][$HEX][$HEX][$HEX][$HEX][$HEX][$HEX][$HEX][$HEX][$HEX][$HEX])
			MOBILE="0176/24223419"
			FROM="bwireless))"
		;;
		'0'[0-9][0-9]*)
			# 0176/...
			MOBILE="$MAC"
			FROM="bwireless))"
		;;
		*)
			log "file not found '$FILE' MAC: '$MAC'"
			exit 1
		;;
	esac
fi

FILE="/var/www/networks/$NETWORK/settings/${MAC}.sms"
if [ -e "$FILE" ]; then
	read -r NUMBER <"$FILE"
else
	FILE="/var/www/networks/$NETWORK/contact.txt"
	[ -z "$MOBILE" ] && {
		[ -e "$FILE" ] && {
			eval "$( grep ^"MOBILE=" "$FILE" )"
			eval "$( grep ^"FROM=" "$FILE" )"
		}
	}

	if [ -z "$MOBILE" ]; then
		log "file not found/useable '$FILE'"
		exit 1
	else
		NUMBER="$MOBILE"
		log "Using global contact: $NUMBER from: $FROM for MAC: $MAC"
	fi
fi

url_encode()
{
	local text="$1"
	local pos char

	while [ ${pos:-0} -lt ${#text} ]; do {
		pos=$(( pos + 1 ))
		char="$( echo "$text" | cut -b $pos )"

		case "$char" in
			"_"|"."|"~"|"-")
				echo -n "$char"
			;;
			[A-Za-z0-9])
				echo -n "$char"
			;;
			" ")
				echo -n "+"
			;;
			*)
				echo -n "%$( echo "$char" | hexdump -C | cut -d' ' -f3 | head -n1 )"
			;;
		esac
	} done
}

case "$TEMPLATE" in
	1|restart_node)
		TEXT="Stoerung der WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE festgestellt: bitte Neustarten: Stromstecker ziehen und wieder einstecken. Danke"
	;;
	2|check_wiredlan)
		TEXT="Stoerung der WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE festgestellt: bitte nachsehen, ob Netzwerkkabel an beiden Geraeten steckt. Danke"
	;;
	3|error_gateway)
		TEXT="Stoerung der WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE festgestellt: bitte pruefen, ob das Internet geht, ggf. Neustarten. Danke"
	;;
	4|error_fritzbox)
		TEXT="Stoerung der WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE festgestellt: bitte die schwarze Fritzbox neustarten. Danke"
	;;
	5|maintenance_start)
		TEXT="Wartungsarbeiten an der WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE gestartet - wir melden uns, wenn dies abgeschlossen ist. Danke"
	;;
	6|maintenance_ready)
		TEXT="Wartungsarbeiten an der WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE beendet. Der Netzknoten ist wieder einsatzbereit, danke fuer Ihre Geduld."
	;;
	7|upgrade_done)
		TEXT="WLAN-Einrichtung $NETWORK: Eine Softwareaktualisierung wurden auf allen Geraeten durchgefuehrt"
	;;
	8|error_fixed)
		TEXT="Problem an WLAN-Einrichtung $NETWORK/$HOSTNAME/No.$NODE wurde behoben. Vielen Dank fuer Ihr mitwirken."
	;;
	*)
		TEXT="$TEMPLATE"
	;;
esac

TYPE="quality"
# TYPE="basicplus"

case "$TYPE" in
	quality)	# absender frei waehlbar	// 7.9 cent
		if [ -n "$FROM" ]; then
			FROM="$( url_encode "$( echo "$FROM" | sed 's/[^a-zA-Z0-9]//g' | cut -b 1-11 )" )"
		else
			FROM="$NETWORK"
		fi

		URL="http://www.sms77.de/gateway/?type=$TYPE&from=$FROM"
	;;
	basicplus)	# antworten gehen auf email	// 3.5 cent
		URL="http://www.sms77.de/gateway/?type=$TYPE"
	;;
esac

[ -z "$USER" -o -z "$PASS" ] && exit 1

log "Nummer: '$NUMBER' Zeichen: ${#TEXT}: '$TEXT' url: '$URL'"

TEXT="$( url_encode "$TEXT" )"
NUMBER="$( echo "$NUMBER" | sed 's/[^0-9]//g' )"

log "Nummer: $NUMBER Zeichen: ${#TEXT}: $TEXT"

while true; do {
	ERROR="$( wget --timeout=5 -qO - "${URL}&u=${USER}&p=${PASS}&to=${NUMBER}&text=${TEXT}" )"

	case "$ERROR" in
		100)
			date +%s >"/var/www/networks/$NETWORK/settings/${MAC}.lastsend"
			[ -n "$FEEDBACK" ] && {
				touch "/var/www/networks/$NETWORK/settings/${MAC}.feedback"
				log "feedback-mode activated of node comes up again"
			}
			log "OK"
			exit 0
		;;
		201|202|300|900|301|304|305|307|400|401|902|903|500|600|700|801|802|803|902|903)
			log "ERROR '$ERROR' - abort"
			exit 1
		;;
		402|*)
			log "ERROR '$ERROR' - trying again in 180 secs"
			sleep 180
		;;
	esac
} done

exit 0
