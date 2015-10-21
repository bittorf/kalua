#!/bin/sh

# manuell:
#                 for D in $(ls -l /var/www/$SUB | grep ^d | while read LINE; do set -- $LINE; echo $9; done); do du -sh "/var/www/$D"     ; done
# SUB='networks'; for D in $(ls -l /var/www/$SUB | grep ^d | while read LINE; do set -- $LINE; echo $9; done); do du -sh "/var/www/$SUB/$D"; done


BASEDIR="${1:-/var/www/networks}"
OPTION="$2"		# e.g. 'all' or 'whatever'
MAX_SIZE="5M"		# find-syntax

[ -z "$OPTION" ] && {
	echo "# omitting all *-vds-* files, call with '$0 \"\" all' to show everything"
	echo "Usage: $0 <basedir> <option> <size>"
	echo " e.g.: $0 /var/www/networks whatever 10M"
	exit 1
}

for DIR in $( ls -1 "$BASEDIR" ); do {

	find 2>/dev/null "$BASEDIR/$DIR" -type f -size +$MAX_SIZE |
	 while read -r LINE; do {
		case "$LINE" in
			*"-vds"*|*".ulog"*)
				[ "$OPTION" = "all" ] && ls -lh "$LINE"
			;;
			*)
				ls -lh "$LINE"		# h = humanreadable filesize
			;;
		esac
	 } done
} done

list_networks()
{
        find /var/www/networks/ -type d -name registrator | cut -d'/' -f5 | sort
}

show_megabytes_only()
{
	while read -r LINE; do {
		set -- $LINE
		case "$1" in
			*'M'|*'G')
				echo $LINE
			;;
		esac
	} done
}

echo "[START] vds"
for NETWORK in $( list_networks ); do {
        DIR="/var/www/networks/$NETWORK/vds"
	du -sh "$DIR" | show_megabytes_only
} done
echo "[READY] vds"

echo
echo "[START] size network"
for NETWORK in $( list_networks ); do {
	DIR="/var/www/networks/$NETWORK"
	du -sh "$DIR" | show_megabytes_only
} done
echo "[READY] size network"


echo
echo "[START] size media"
for NETWORK in $( list_networks ); do {
	DIR="/var/www/networks/$NETWORK/media"
	du -sh "$DIR" | show_megabytes_only
} done
echo "[READY] size media"

echo
echo "[START] size special"			# ls -1 | grep -v '01_' | while read LINE; do rm $LINE; done
for DIR in /root/backup/ejbw/pbx foo; do {
	[ -d "$DIR" ] && du -sh "$DIR" | show_megabytes_only
} done
echo "[READY] size media"
