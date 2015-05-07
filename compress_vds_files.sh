#!/bin/sh

# - log/log schrumpfen
#
# /etc/init.d/apache2 stop
# find /var/www/networks -type f -name meshrdf.txt | while read FILE; do rm $FILE; touch $FILE; chmod 777 $FILE; done
# /etc/init.d/apache2 start
#
#
# vertrauen:
# scp -P 10022 .ssh/id_rsa.pub root@87.171.45.240:/tmp
# auf server:
# cat /tmp/id_rsa.pub >>.ssh/authorized_keys


log()
{
	logger -s "$(date) $0: $1"
}

list_networks()
{
	local pattern1="/var/www/networks/"
	local pattern2="/meshrdf/recent"

	find /var/www/networks/ -name recent |
	 grep "meshrdf/recent"$ |
	  sed -e "s|$pattern1||" -e "s|$pattern2||"
}

free_diskspace()
{
	df -h | grep ^/dev/xvda1
}

cleanup_disc()
{
	log "[START] cleanup_disc"
	/etc/init.d/apache2 stop
	rm /var/log/apache2/access.log
	rm /var/log/apache2/error.log
	rm /tmp/write_meshrdf.*

	# see /var/www/scripts/meshrdf_accept.php
	mv '/tmp/monilog.txt' "/var/www/files/openwrt/monilog_$( date +%Y%b%d ).txt"
	touch '/tmp/monilog.txt'
	chmod 777 '/tmp/monilog.txt'
	bzip2 "/var/www/files/openwrt/monilog_$( date +%Y%b%d ).txt"

	/etc/init.d/apache2 start
	log "[READY] cleanup_disc"
}

case "$1" in
	"")
		echo "Usage: $0 <start|check|networkname>"
		echo
		echo "loops over:"
		list_networks
		exit 1
	;;
	start|check)
		LIST_NETWORKS="$( list_networks )"
	;;
	*)
		LIST_NETWORKS="$1"
	;;
esac

cleanup_disc

for NETWORK in $LIST_NETWORKS; do {
	du -sh "/var/www/networks/$NETWORK/vds"

	[ "$1" = "check" ] && continue

	cd "/var/www/networks/$NETWORK/vds"
	BACKUP="backup_vds_$( date +%Y%b%d_%H:%M ).tar.lzma"
	log "[START] working on $NETWORK: $( free_diskspace ) in dir: '$( pwd )'"

	find . -size -500c | fgrep "db_backup.tgz_" |
	 while read FILE; do {
		log "deleting too small db-backup: $FILE <500 bytes"
		rm -f "$FILE"
	 } done

	ls -1 *.tar | while read TAR; do {
		ls -l ./$TAR
		lzma ./$TAR
	} done

	ls -1 backup_vds_$( date +%Y%b%d)* && {
		log "[ERR] backup is from today, do nothing, check: $( pwd )/backup_vds_*"
#		continue
	}

	rm "/tmp/compress_vds_*"
#	rm ../meshrdf/meshrdf.txt

	ls -1 | grep ^"user-"			 >"/tmp/compress_vds_$$"
	ls -1 *.$( date +%Y )*			>>"/tmp/compress_vds_$$"
	ls -1 db_backup.tgz_*.2012*		>>"/tmp/compress_vds_$$"
	ls -1 db_backup.tgz_*.2013*		>>"/tmp/compress_vds_$$"
	ls -1 ../log/log.txt			>>"/tmp/compress_vds_$$"
	ls -1 ../media/traffic_*		>>"/tmp/compress_vds_$$"
	ls -1 ../media/map_topology_*		>>"/tmp/compress_vds_$$"
	ls -1 ../registrator/registrator.txt			>>"/tmp/compress_vds_$$"
	ls -1 ../meshrdf/meshrdf-monthquadruple-* 	 	>>"/tmp/compress_vds_$$"
	ls -1 ../meshrdf/meshrdf-year-*				>>"/tmp/compress_vds_$$"
	ls -1 ../meshrdf/recent/*.wifiscan			>>"/tmp/compress_vds_$$"
	ls -1 ../meshrdf/meshrdf.txt				>>"/tmp/compress_vds_$$"
	find /var/www/networks/spbansin/media/pix_old -type f	>>"/tmp/compress_vds_$$"
	find /var/www/networks/spbansin/media/webcam_movies/ -type f >>"/tmp/compress_vds_$$"

	ls -1 backup_vds_$( date +%Y%b%d )* || {
		tar -T /tmp/compress_vds_$$ --lzma -cf ./$BACKUP
		ls -l ./$BACKUP
	}

	log "[DELETING]"
	sed -i 's/^/rm /' "/tmp/compress_vds_$$"
	.  "/tmp/compress_vds_$$"
	rm "/tmp/compress_vds_$$"

	log "[READY] $NETWORK: $( free_diskspace )"
} done
