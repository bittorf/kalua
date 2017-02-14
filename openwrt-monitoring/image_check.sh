#!/bin/sh

# http://intercity-vpn.de/networks/spbansin/media/1.jpg (generated from 47.jpg)

[ "$PWD" = '/var/www/networks/spbansin/media' ] || exit 1

OUTFILE='1.jpg'
MAXAGE=14400		# 4 hours (use samplepic if we have no new pictures)
CRC=
CRC_OLD='unset'
INTERVAL=93
CHECKFILE='47.jpg'

while true; do {
	# TODO: this is racy - better work with a temp-copy
	# first check if file is ready uploaded (can last really long)
	# e.g. cam_47-stream-id_1455011616-2016_Feb_09-from_10h53m_to_11h34m.mp4
	INFILE="$( ls 2>/dev/null -1t cam* | head -n1 )"
	CRC="$CRC_OLD"
	logger -s "checking infile '$INFILE'"
	if [ -e "$INFILE" ]; then
		CRC="$( md5sum "$INFILE" | cut -d' ' -f1 )"
	else
		UNIXTIME_OLD="$( stat --printf %Y "$OUTFILE" )"
		UNIXTIME_NOW="$( date +%s )"
		[ $(( UNIXTIME_NOW - UNIXTIME_OLD )) -gt $MAXAGE ] && {
			logger -s "very old camfile, using 'normalized2.jpg'"
			cp "normalized2.jpg" "$OUTFILE"
			touch "$OUTFILE"
		}

		CRC="$CRC_OLD"
	fi

	if [ "$CRC" = "$CRC_OLD" ]; then
		logger -s "using '$CHECKFILE' - $( ls -l "$CHECKFILE" )"
		cp "$CHECKFILE" 'normalized.jpg'

		mv "normalized.jpg" "$OUTFILE"		# FIXME?!
		logger -s "used 'normalized.jpg' for '$OUTFILE'"
	else
		logger -s "$(date) crc changed - file: '$INFILE'"

		CRC_OLD="$CRC"
		convert "$INFILE" 'test.png' 2>&1 | grep -q 'Corrupt' || {
			logger -s "$( date ) new pic '$INFILE' seems valid"

			if convert "$INFILE" -channel R -normalize -channel G -normalize -channel B -normalize "normalized.jpg"; then
				mv "normalized.jpg" "$OUTFILE"
				logger -s "$( date ) converted '$INFILE' to 'normalized.jpg'"
			else
				logger -s "$( date ) error $? during normalizing"
			fi
		}

		DATE="$( date +20%y-%b-%d )"
		mkdir -p webcam_movies/$DATE
		[ -n "$( ls -1 'cam_1-stream'* )" ] && mv 'cam_1-stream'* webcam_movies/$DATE/

		mkdir -p pix_old/$DATE
		[ -n "$( ls -1 cam* )" ] && {		# too many arguments
			for FILE in cam*; do {
				logger -s "mv \"$FILE\" pix_old/$DATE/"
				mv "$FILE" pix_old/$DATE/
			} done
		}
	fi

	logger -s "waiting $INTERVAL seconds"
	sleep $INTERVAL
} done
