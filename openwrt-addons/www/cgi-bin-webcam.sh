#!/bin/sh
. /tmp/loader

cd /webcam || exit

_http header_mimetype_output 'application/x-tar' "webcam_${ANYADR}_$( date +%s ).tar"

LIST="$TMPDIR/webcam_filelist.txt"
# e.g. 02-20161209142507-01.jpg
ls -1t *.jpg | grep -v 'lastsnap.jpg' >"$LIST"

[ -s "$LIST" ] && {
	# e.g. download with 'wget --content-disposition http://$IP/cgi-bin-webcam.sh'
	tar -c -T "$LIST" -f -

	while read -r FILE; do {
		test -e "$FILE" -a "$FILE" != 'webcam.jpg' && {
			rm "$FILE"
		}
	} done <"$LIST"
}

rm "$LIST"
