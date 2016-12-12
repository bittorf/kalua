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

pics2movie()
{
	local file
	local line i=0

	mkdir 'pix' || return		# plain .jpg's from tar-files
	mkdir 'frames' || return	# sanitized pics converted to .png

	for file in *.tar; do {
		tar -C 'pix' -xf "$file" || echo "error in '$file'"

		cd 'pix' || return 1
		ls -1 >"../frames/files.txt"
		while read -r line; do {
			mv "$line" "../frames/img-$( date +%s -r "$line" ).jpg"
			i=$(( i + 1 ))
		} done <"../frames/files.txt"
		cd - >/dev/null || return
	} done

	cd frames || return
	i=0
	ls -1rt | while read -r line; do {
		# TODO: enforce '1280x720' and RGB24?
		convert "$line" "img-$( printf '%05d' "$i" ).png" && i=$(( i + 1 ))
		rm "$line"
	} done

	ffmpeg -r 60 -f image2 -i img-%05d.png -vcodec libx264 -crf 15 -pix_fmt yuv420p ../out.mp4
	cd - >/dev/null || return
	rm -fR 'pix' 'frames'
}
