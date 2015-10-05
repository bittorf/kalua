#!/bin/sh

# - Ausgang:
# meshrdf.txt
# - zeilenweise durchgehen und zeitlich passend neu aufteilen in:
# meshrdf_week23.txt
# - dann jeweils 4 wochen einpacken:
# meshrdf-monthquadruple-13.tar.bz2
# - im neuen jahr, das alte in ein tar
# meshrdf-year-2010.tar
# - fertig!

FILE="$1"

[ -z "$FILE" ] && {
	echo "Usage: $0 <path_to_meshrdf.txt>"
	exit 1
}

log ()
{
	logger -s "$0: $1"
}

unixtime2week ()
{
	local UNIXTIME="$1"

	date --date @$UNIXTIME +%V
}

unixtime2year ()
{
	local UNIXTIME="$1"

	date --date @$UNIXTIME +%Y
}

unixtime_seems_plausi ()
{
	local UNIXTIME_OLD="$1"
	local UNIXTIME_NEW="$2"

	[ -z "$UNIXTIME_OLD" ] && return 0
	[ -z "$UNIXTIME_NEW" ] && return 1

	YEARDIFF="$(( $( unixtime2year $UNIXTIME_NEW ) - $( unixtime2year $UNIXTIME_OLD ) ))"
	[ $YEARDIFF -gt 1 -o $YEARDIFF -lt -1 ] && return 1

	return 0
}

compress ()
{
	local MONTH_QUADRUPLE="$1"
	local ARG1="$2"
	local WEEK_NOW="$( date +%V )"		# turn of year

	[ "$WEEK_NOW" = "02" ] && {
		WEEK_NOW=55				# real_week - last_week_found must be >1
	}

	local FILE
	local LIST_FILES

	shift
	while [ -n "$ARG1" ]; do {
		FILE="$WORKINGDIR/meshrdf_week${ARG1}.txt"

		[ -e "$FILE" ] && {
			logger -s "adding '$FILE'"
			LIST_FILES="$LIST_FILES $FILE"
		}

		shift
		[ -z "$1" -a -n "$LIST_FILES" ] && {
			[ $(( $WEEK_NOW - $ARG1 )) -gt 1 ] && {		# only compress, if older than 1 week
			
				log "trying to .tar.bz2 $LIST_FILES"

				if tar cvjf $WORKINGDIR/meshrdf-monthquadruple-${MONTH_QUADRUPLE}.tar.bz2 $LIST_FILES ; then
					rm $LIST_FILES
				else
					log "error during tar $LIST_FILES"
				fi
			}
		}

		ARG1="$1"
	} done
}

WORKINGDIR="$( dirname "$FILE" )"
mv $FILE ${FILE}.workingcopy
touch $FILE
chmod 777 $FILE
FILE="${FILE}.workingcopy"


while read -r LINE; do {

	log "attempting to eval \"$LINE\""
	eval "$LINE"
	unixtime_seems_plausi "$UNIXTIME_OLD" "$UNIXTIME" || UNIXTIME="$UNIXTIME_OLD"

	echo "$LINE" >>"$WORKINGDIR/meshrdf_week$( unixtime2week $UNIXTIME ).txt"

	[ -n "$UNIXTIME" ] && UNIXTIME_OLD="$UNIXTIME"

} done <"$FILE" && rm "$FILE"


for WEEK_QUADRUPLE in 1 2 3 4 5 6 7 8 9 10 11 12 13; do {

	case $WEEK_QUADRUPLE in
		1) compress  1  1  2  3  4 ;;
		2) compress  2  5  6  7  8 ;;
		3) compress  3  9 10 11 12 ;;
		4) compress  4 13 14 15 16 ;;
		5) compress  5 17 18 19 20 ;;
		6) compress  6 21 22 23 24 ;;
		7) compress  7 25 26 27 28 ;;
		8) compress  8 29 30 31 32 ;;
		9) compress  9 33 34 35 36 ;;
	       10) compress 10 37 38 39 40 ;;
	       11) compress 11 41 42 43 44 ;;
	       12) compress 12 45 46 47 48 ;;
	       13) compress 13 49 50 51 52 53 ;;
	esac
} done


[ -e "$WORKINGDIR/meshrdf_week01.txt" ] && {

	[ -e "$WORKINGDIR/meshrdf-monthquadruple-13.tar.bz2" ] && {

		THISYEAR="$( date +%Y )"
		LASTYEAR="$(( $THISYEAR - 1 ))"
		TARFILE="$WORKINGDIR/meshrdf-year-${LASTYEAR}.tar"

		log "finishing the hole year $LASTYEAR, tar'ing to $TARFILE"

		if tar cvf $TARFILE $WORKINGDIR/meshrdf-monthquadruple-* ; then
			rm $WORKINGDIR/meshrdf-monthquadruple-*
		else
			log "[ERR] tar cvf $TARFILE $WORKINGDIR/meshrdf-monthquadruple-*"
		fi
	}
}
