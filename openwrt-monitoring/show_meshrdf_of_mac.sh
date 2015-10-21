#!/bin/sh

FILE="$1"
OPTION="$2"

[ -e "${FILE:-unset}" ] || {
	echo "Usage: $0 <path-to-meshrdf/mac> [neighs]"
	exit
}

sed 's/;/\n/g' "$FILE" | while read -r LINE; do {
	case "$OPTION" in
		"neighs")
			case "$LINE" in
				"NEIGH="*)
					echo $LINE | sed 's/[~=-]/\n/g'
				;;
			esac
		;;
		*)
			echo "$LINE"
		;;
	esac
} done
