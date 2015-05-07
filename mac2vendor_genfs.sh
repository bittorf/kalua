#!/bin/sh

# 00-00-00   (hex)                XEROX CORPORATION
# 000000     (base 16)            XEROX CORPORATION
#                                 M/S 105-50C
#                                 800 PHILLIPS ROAD
#                                 WEBSTER NY 14580
#                                 UNITED STATES

URL="http://standards.ieee.org/regauth/oui/oui.txt"
TEMP="/tmp/oui_$$"
DIR="/var/www/oui"
FILE="/tmp/oui.txt"

mkdir -p "$DIR"
[ -s "/var/www/oui/api.txt" ] || ln -s "/var/www/scripts/mac2vendor_genfs.api.txt" "/var/www/oui/api.txt"
wget -qO "$FILE" "$URL"

HEX="[0-9a-fA-F]"
OUI="$HEX$HEX-$HEX$HEX-$HEX$HEX"
ALL=0
NEW=0

while read LINE; do {
	case "$LINE" in
		"")
			if [ -n "$LINE1" ]; then
				[ -e "$DIR/$BYTE1/$BYTE2/$BYTE3" ] || {
					NEW=$(( $NEW + 1 ))
					mkdir -p            "$DIR/$BYTE1/$BYTE2"
					cp "$TEMP"          "$DIR/$BYTE1/$BYTE2/$BYTE3"
					mkdir -p "$(   echo "$DIR/$BYTE1/$BYTE2"        | sed 'y/ABCDEF/abcdef/' )"
					mv "$TEMP" "$( echo "$DIR/$BYTE1/$BYTE2/$BYTE3" | sed 'y/ABCDEF/abcdef/' )"
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
			ALL=$(( $ALL + 1 ))
			set -- $LINE			# '01-23-45   (hex)                blabla'
			BYTE1="${LINE%%-*}"		# '01'
			BYTE2="${LINE#*-}"		# '23-45 ...'
			BYTE3="${BYTE2#*-}"		# '45 ...'
			BYTE2="${BYTE2%%-*}"		# '23'
			set -- $BYTE3
			BYTE3="$1"			# '45'
			shift 2
			LINE1="$@"
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
rm "$FILE"

sed -i "s/update on server @ .*/update on server @ $(date)/" /var/www/scripts/mac2vendor_genfs.api.txt
logger -s "$0: $ALL oui parsed, $NEW new detected"
