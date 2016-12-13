#!/bin/sh
. /tmp/loader

cd /webcam || exit

_http header_mimetype_output 'application/x-tar' "webcam_${ANYADR}_$( date +%s ).tar"

LIST="$TMPDIR/webcam_filelist.txt"
# e.g. 02-20161209142507-01.jpg
# find . -type f -name '*.jpg' | grep -v 'lastsnap.jpg' >"$LIST"
ls -1t *'.jpg' | grep -v 'lastsnap.jpg' >"$LIST"

[ -s "$LIST" ] && {
	read -r FILE <"$LIST"			# most recent
	END_MARKER="$( printf "\xFF\xD9" )"
	FILE_END="$( tail -c2 "$FILE" )"
	test "$END_MARKER" = "$FILE_END" || BADFILE="$FILE"	# we do not remove it later, if not fully written

	# e.g. download with 'wget --content-disposition http://$IP/cgi-bin-webcam.sh'
	tar -c -T "$LIST" -f -

	while read -r FILE; do {
		# test "$END_MARKER" = "$FILE_END"
		test -e "$FILE" -a "$FILE" != 'webcam.jpg' && {
			test "$FILE" = "$BADFILE" || rm "$FILE"
		}
	} done <"$LIST"
}

rm "$LIST"

pics2movie()
{
	local file timestamp line j=0 i=0 oldest=0 newest=9999999999

	mkdir 'pix' || return		# plain .jpg's from tar-files
	mkdir 'frames' || return	# sanitized pics converted to .png

	# TODO: do most in ram-disc?
	# TODO: show progress
	# unpack every tar and throw all files into 1 dir
	for file in *.tar; do {
		j=$(( j + 1 ))
		tar -C 'pix' -xf "$file" || logger -s "error in '$file'"
		rm "$file"

		cd 'pix' || return 1
		ls -1 >"../frames/files.txt"
		while read -r line; do {
			timestamp="$( date +%s -r "$line" )"
			test $timestamp -gt $oldest && oldest=$timestamp
			test $timestamp -lt $newest && newest=$timestamp

			mv "$line" "../frames/img-$( date +%s -r "$line" ).jpg"
			i=$(( i + 1 ))
		} done <"../frames/files.txt"
		cd - >/dev/null || return
	} done
	logger -s "all files: $i in $j tars - oldest=$oldest=$( date -d @$oldest ) newest=$newest=$( date -d @$newest )"

	# sanitize each picture
	cd frames || return
	j=0
	ls -1rt | while read -r file; do {
		convert "$file" -resize 1280x720 -depth 24 "img-$( printf '%05d' "$j" ).png" && j=$(( j + 1 ))
		logger -s "convert: $j/$i"
		rm "$file"
	} done
	logger -s "all files: $i files ok: $( ls -l *.png | tail -n1 ) oldest: $oldest newest: $newest"

	ffmpeg -r 60 -f image2 -i img-%05d.png -vcodec libx264 -crf 15 -pix_fmt yuv420p "../out.mp4"
	cd - >/dev/null || return
	rm -fR 'pix' 'frames'
}
