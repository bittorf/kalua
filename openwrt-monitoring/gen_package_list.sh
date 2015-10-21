#!/bin/sh

ARG1="$1"		# e.g. 'start'
OPTION="$2"		# e.g. 'strip'
MYPWD=
DIR=

[ -z "$ARG1" ] && {
	echo "Usage: $0 start		# builds 'Packages' from all *.ipk-files in actual DIR"
	echo "       $0 start strip		# same, but only shows elementary tags: Package|Version|Filename"
	echo "       $0 name		# builds 'Packages' for network 'name'"
	exit 1
}

# typical (alphabetical) order is:
# fff-adblock-list mydesign mysettings sshpubkeys

[ -d "/var/www/networks/$ARG1" ] && {
	MYPWD="$( pwd )"
	DIR="/var/www/networks/$ARG1/packages"
	logger -s "$0: working in: '$DIR'"
	cd "$DIR" || exit
}

# fixme! when in 'strip'-mode, make an directory mini/
# and copy all packages in there, after fetching control-file
# and rename to a.ipk b.ipk c.ipk
# namespace when using:
# a-zA-Z0-9     = 26 + 26 + 10 = 62 files
# a-zA-Z0-9 x 2 = 3844 files

OUT="Packages"
[ -e "$OUT" ] && rm "$OUT"

for FILE in $( ls -1 *.ipk ); do {
	tar xzf "$FILE" ./control.tar.gz
	tar xzf control.tar.gz ./control

	case "$OPTION" in
		strip)
			LINE=
			grep -v ^" " control | grep -v "^$" | while read -r LINE; do {
				case "${LINE%: *}" in
					Package|Version)
						echo "$LINE" >>"$OUT"
					;;
				esac
			} done
			
			stat >>"$OUT" --printf "Filename: %n\n\n" "$FILE"
		;;
		*)
			grep -v ^" " control | grep -v "^$" >>"$OUT"	# strip lines beginning with space and empty lines
			stat >>"$OUT" --printf "Size: %s\nFilename: %n\n\n" "$FILE"
		;;
	esac

	rm -f "control" "control.tar.gz"
} done

ls -l "$OUT"
[ -n "$MYPWD" ] && cd $MYPWD
