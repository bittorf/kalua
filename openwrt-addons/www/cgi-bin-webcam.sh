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

	mkdir 'pix' 'frames'

	for file in *.tar; do {
		tar -C 'pix' -xf "$file" || echo "error in '$file'"

		cd 'pix' || return 1
		ls -1rt >../frames/files.txt
		while read -r line; do {
			mv "$line" "../frames/img-$( printf '%05d' "$i" ).jpg"
			i=$(( i + 1 ))
		} done <../frames/files.txt
		cd - >/dev/null
	} done

	ffmpeg -r 60 -f image2 -i frames/img-%05d.jpg -vcodec libx264 -crf 15 -pix_fmt yuv420p out.mp4
	rm -fR 'pix' 'frames'
}
