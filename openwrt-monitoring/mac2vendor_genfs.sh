#!/bin/sh

# 00-00-00   (hex)                XEROX CORPORATION
# 000000     (base 16)            XEROX CORPORATION
#                                 M/S 105-50C
#                                 800 PHILLIPS ROAD
#                                 WEBSTER NY 14580
#                                 UNITED STATES

URL="$1"
KEEP=

[ -z "$URL" ] && {
	URL='http://standards.ieee.org/regauth/oui/oui.txt'
	URL='http://standards.ieee.org/develop/regauth/oui/oui.txt'
#	URL='https://code.wireshark.org/review/gitweb?p=wireshark.git;a=blob_plain;f=manuf'
}

TEMP="/tmp/oui_$$"
DIR="/var/www/oui"
FILE="/tmp/oui.txt"
API='/var/www/scripts/mac2vendor_genfs.api.txt'
API_LINK='/var/www/oui/api.txt'

mkdir -p "$DIR"
[ -s "$API_LINK" ] || ln -s "$API" "$API_LINK"

if [ -e "$URL" ]; then
	KEEP='true'
	FILE="$URL"
else
	wget -O "$FILE" "$URL"
fi

CARRIAGE_RETURN="$( printf '\r' )"
HEX="[0-9a-fA-F]"
OUI="$HEX$HEX-$HEX$HEX-$HEX$HEX"
ALL=0
NEW=0
I=0
J=0

while read -r LINE; do {
	I=$(( I + 1 ))
	case "$LINE" in
		*$CARRIAGE_RETURN*)
			J=$(( J + 1 ))
			LINE="$( echo "$LINE" | tr -d '\r' )"
		;;
	esac

	case "$LINE" in
		'')
			if [ -n "$LINE1" ]; then
				[ -e "$DIR/$BYTE1/$BYTE2/$BYTE3" ] || {
					NEW=$(( NEW + 1 ))
					mkdir -p            "$DIR/$BYTE1/$BYTE2"					# dir/AA/BB
					cp "$TEMP"          "$DIR/$BYTE1/$BYTE2/$BYTE3"					# dir/AA/BB/CC (txtfile)
					mkdir -p "$(   echo "$DIR/$BYTE1/$BYTE2"        | sed 'y/ABCDEF/abcdef/' )"	# dir/aa/bb
					mv "$TEMP" "$( echo "$DIR/$BYTE1/$BYTE2/$BYTE3" | sed 'y/ABCDEF/abcdef/' )"	# dir/aa/bb/cc (txtfile)
				}
			else
				LINE1=
			fi
		;;
		*"(base 16)"*)
#			set -- $LINE			# '000000     (base 16)            XEROX CORPORATION'
#			shift 3
#			echo >>"$TEMP" "$@"		# first 2 lines are always equal, last 2 sometimes
		;;
		$OUI*)
			ALL=$(( ALL + 1 ))
			set -- $LINE			# '01-23-45   (hex)                blabla'
			BYTE1="${1%%-*}"		# '01'
			BYTE2="${1#*-}"			#    '23-45 ...'
			BYTE3="${BYTE2#*-}"		#       '45 ...'
			BYTE2="${BYTE2%%-*}"		#    '23'

			shift 2
			LINE1="$*"
			echo  >"$TEMP" "$LINE1"
		;;
		*)
			[ -z "$LINE1" ] || {
				set -- $LINE		# '                                WEBSTER NY 14580'
				[ "$LASTLINE" = "$LINE" ] || {
					LASTLINE="$LINE"
					echo >>"$TEMP" "$@"
				}
			}
		;;
	esac
} done <"$FILE"

[ -z "$KEEP" -a -e "$FILE" ] && rm "$FILE"
[ -e "$TEMP" ] && rm "$TEMP"

sed -i "s/update on server @ .*/update on server @ $(date)/" "$API"
logger -s "$0: $I/$J lines from '$FILE' and $ALL oui parsed, $NEW new detected"
logger -s "$0: wrote: $API into dir $DIR/"
