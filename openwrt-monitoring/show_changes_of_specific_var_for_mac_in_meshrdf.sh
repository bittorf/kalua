#!/bin/sh

FILE="$1"
MAC="$2"	# 001122334455
VARNAME="$3"
VARNAME2="$4"

[ -z "$MAC" ] && {
	echo "Usage: $0 <file|network> <mac> <varname> <varname_additionally_show>"
	exit 1
}

case "$FILE" in
	*"/"*)
		:
	;;
	*)
		FILE="/var/www/networks/$FILE/meshrdf/meshrdf.txt"
	;;
esac

unixtime2date()		# needs 'gawk' NOT the 'mawk'
{
	awk -v UNIXTIME="$1" 'BEGIN { print strftime("%c", UNIXTIME) }'
}

while read -r LINE; do {
	LINECOUNT=$(( $LINECOUNT + 1 ))

	case "$LINE" in
		*"$MAC"*)		# WIFIMAC="00156d1aaebc"
			eval $LINE

			value_now="$( eval echo \$$VARNAME )"
			[ "$value_now" = "$value_old" ] || {
				[ -n "$VARNAME2" ] && varname2="$( eval echo \$$VARNAME2 )"
				echo "$( unixtime2date $UNIXTIME ): $value_now $varname2"
			}
			value_old="$value_now"
		;;
	esac

} done <"$FILE"

echo "[OK] checked ${LINECOUNT:-0} lines in file '$FILE'"

[ -n "$LINE" ] && {
	echo "never found data for device '$MAC'"
}
