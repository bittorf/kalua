#!/bin/sh
#
# hoffmann, kirchgasse: 940c6dfe5eb8 d85d4ca4e992
# 

LIST_MACS="$1"
LIST_FILES="$2"		# e.g. /var/www/networks/rehungen/meshrdf/meshrdf_week01*

[ -z "$LIST_FILES" ] && {
	echo "Usage: $0 '<list_macs>' '<meshrdf_files>' <mode>		# mac must be without colons (':')"
	exit 1
}

for FILE in $LIST_FILES; do {

	echo "working on file '$FILE'"

	while read LINE; do {

		eval $LINE

		case "$LIST_MACS" in
			*$WIFIMAC*)
				case "$SENS" in
					0mb) : ;;
					*)
						# nur letzten wert ausgeben, wenn wert kleiner geworden ist
						TRAFF_THIS="${SENS%*mb}"
						[ "$TRAFF_THIS" != "$TRAFF_LAST" ] && {
							echo "$WIFIMAC: $HUMANTIME $SENS"
						}
						TRAFF_LAST="${SENS%*mb}"
					;;
				esac

				WIFIMAC=
			;;
		esac
		
	} done <$FILE
	
} done
