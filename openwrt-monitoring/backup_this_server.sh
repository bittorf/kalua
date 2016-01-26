#!/bin/sh

SCP_SPECIAL_OPTIONS="-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no"
STARTDATE="$( date )"

log()
{
	logger -s "$0: $1"
}

tar()
{
	local rc

	log "starting tar: $*"
	/etc/init.d/apache2 stop

	command tar "$@"
	rc=$?

	/etc/init.d/apache2 start
	log "tar_ready: rc = $rc"

	return $rc
}

list_pubips_from_network()
{
	local network="$1"
	local dir="/var/www/networks/$network/meshrdf/recent"
	local file

	# TODO: e.g. if 'satama', also block 'marinapark'

	for file in $( ls -1 $dir | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ ); do {
		[ -e "$file" ] && {
			. "$dir/$file"
			echo "$PUBIP_REAL"
		}

		[ -e "$dir/$file.changes" ] && {
			. "$dir/$file.changes"
			echo "$PUBIP_REAL"
		}

		PUBIP_REAL=
	} done | sort | uniq
}

list_networks()
{
	local network line file

	if [ -e "/var/www/networks/${ARG2:-not_existent}" ]; then
		echo "$ARG2"
	else
		# sort: network with smallest size first
		ls -1 /var/www/networks | while read -r network; do {
			for file in /var/www/networks/$network/meshrdf/recent/*; do {
				[ -e "$file" ] && {
					# if there is at least 1 file,
					# check *once* size of whole folder
					[ -h "$file" ] || {
						du -s "/var/www/networks/$network"
						break
					}
				}
			} done
		} done | sort -n | while read -r line; do set -- $line; basename "$2"; done | uniq
	fi
}

dns2ip()
{
	nslookup "$1" | grep ^'Address:' | tail -n1 | cut -d' ' -f2
}

ARG="$1"		# BACKUPSERVER|checksize = special keyword
ARG2="${2:-unknown}"	# e.g. satama

case "$ARG2" in
	'all_networks_smallest_first')
		COUNT_NETWORK_ALL=0
		for _ in $( list_networks ); do COUNT_NETWORK_ALL=$(( COUNT_NETWORK_ALL + 1 )); done

		COUNT_NETWORK=0
		for ARG2 in $( list_networks ); do {
			COUNT_NETWORK=$(( COUNT_NETWORK + 1 ))
			log "artificial call: $0 '$ARG' '$ARG2' - network: $COUNT_NETWORK/$COUNT_NETWORK_ALL"
			$0 "$ARG" "$ARG2" || exit 1
		} done

		exit 0
	;;
esac

case "$ARG" in
	'checksize')
		list_networks | while read -r LINE; do {
			du -s "/var/www/networks/$LINE"
		} done

		# for D in /var/www/networks/berlinle/*; do test -d "$D" && du -sh $D; done
		exit 0
	;;
	'BACKUPSERVER2')
		IP='198.23.155.210'
		LIST_IMPORTANT_IPS=" $IP "
		ARG="port22:bastian@${IP}:backup-intercity-vpn"

		log "using ARG2 = $ARG"
	;;
	'BACKUPSERVER')
		# KG-Fries36-AP
		# test with: ssh -p 10022 $user@87.171.8.197

#		. '/var/www/networks/liszt28/meshrdf/recent/74ea3ae44a96'
#		IP="$PUBIP_REAL"
#		LIST_IMPORTANT_IPS=" $IP "
#
#		ARG="port10022:bastian@${IP}:daten/bla/incoming-backup/intercity-vpn"
#		ARG="port10022:root@${IP}:/tmp/hdd/bla/incoming-backup/intercity-vpn"
#		ARG="port10022:root@${IP}:/tmp/storage/sda2_2.0T/bla/incoming-backup/intercity-vpn"
		IP='bwireless.mooo.com'
		LIST_IMPORTANT_IPS=" $( dns2ip "$IP" ) "
		ARG="port10022:root@${IP}:/tmp/kalua/storage/sda1_3.6T/backup_ICVPN"
#		ARG="port22:bastian@bb.weimarnetz.de:backup-ic"

		log "using ARG2 = $ARG"
	;;
	'')
		# read -r IP </var/www/networks/liszt28/meshrdf/recent/76ea3ae44a96.pubip
		# NAS: port10022:bastian@${IP}:daten/bla/incoming-backup/intercity-vpn
		# results in:
		# scp -P 10022 BACKUP/* bastian@${IP}:daten/bla/incoming-backup/intercity-vpn
		# scp -P 10022 BACKUP/* bastian@87.171.23.28:daten/bla/incoming-backup/intercity-vpn

		echo "Usage: $0 <start | user@host.tld | port22:bastian@weimarnetz.de:/mnt/hd/bastian/backups> <network>"
		echo "       $0 checksize"
		echo "       $0 BACKUPSERVER"
		echo "       $0 BACKUPSERVER all_networks_smallest_first"

		exit 1
	;;
esac


# full-backup only, if all (not a specific network) is done
[ -e "/var/www/networks/$ARG2" ] || {
	TARFILE="/tmp/backup-server-$( uname -n )-$( date +%Y%b%d_%H:%M ).tar"		# 2008oct12_20:25

	# trash:
	rm /tmp/all_pubips.txt_*

	cd / || exit
	tar -cvf "$TARFILE" /var/www/scripts /var/spool/cron/crontabs/root /tmp/crashlogs /tmp/monilog.txt
	ls -l $TARFILE
	log "[OK] lzma '$TARFILE' running"
	lzma "$TARFILE"
	TARFILE="$TARFILE.lzma"
	ls -l $TARFILE

	echo
	log "[OK] wrote $TARFILE"
	echo
	echo "now make this on the remote machine:"
	echo
	echo "scp root@intercity-vpn.de:$TARFILE ."
}

[ "$ARG" = "start" ] && {
	log "START: $STARTDATE -> READY: $( date )"
	exit 0
}

case "$ARG" in
	port*)
		PORT="$( echo "$ARG" | cut -d':' -f1 | cut -d't' -f2 )"
		log "using port $PORT"
		ARG="$( echo "$ARG" | cut -d':' -f2,3 )"
		log "ARG now: '$ARG'"
	;;
	*)
		PORT=22
	;;
esac

cd / || exit

[ -e "$TARFILE" ] && {
	echo "scp-ing tarfile $TARFILE to $ARG - pwd: '$( pwd )'"
	echo "scp -P $PORT '$TARFILE' $ARG"

	if scp $SCP_SPECIAL_OPTIONS -P $PORT "$TARFILE" $ARG ; then
		rm "$TARFILE"
	else
		exit 1
	fi
}

# full-backup only, if all (not a specific network) is done
[ -e "/var/www/networks/$ARG2" ] || {
	case "$ARG2" in
		ejbw-pbx)
			TARFILE="/tmp/backup-server-ejbw_pbx-$( uname -n )-$( date +%Y%b%d_%H:%M ).tar.bz2"
			if tar -cvjf "$TARFILE" /root/backup/ejbw/pbx ; then
				echo "scp-ing tarfile $( ls -l $TARFILE ) to $ARG"

				if scp $SCP_SPECIAL_OPTIONS -P $PORT "$TARFILE" $ARG ; then
					rm /root/backup/ejbw/pbx/*
					rm "$TARFILE"
				else
					exit 1
				fi
			else
				exit 1
			fi
		;;
		spbansin)
			for FILE in $( find /var/www/networks/spbansin/media/webcam_movies -type f ); do {
				if scp $SCP_SPECIAL_OPTIONS -P $PORT "$FILE" $ARG ; then
					rm "$FILE"
				else
					exit 1
				fi
			} done
		;;
	esac

	TARFILE="/tmp/backup-server-varwwwother-$( uname -n )-$( date +%Y%b%d_%H:%M ).tar"
	FILELIST="$( find /var/www -maxdepth 1 -mindepth 1 | fgrep -v "/networks" | fgrep -v "/macs" )"

	echo "content: varwwwother creating $TARFILE"
	tar -cf "$TARFILE" $FILELIST || {
		log "error during tar - disc full?"
		log "START: $STARTDATE -> READY: $( date )"
		exit 1
	}

	echo "scp-ing tarfile $TARFILE to $ARG"
	if scp $SCP_SPECIAL_OPTIONS -P $PORT "$TARFILE" $ARG ; then
		rm "$TARFILE"
	else
		exit 1
	fi

	TARFILE="/tmp/backup-server-roothome-$( uname -n )-$( date +%Y%b%d_%H:%M ).tar"
	FILELIST="$( find /root -type f | grep -v 'torrent' )"
	echo "content: roothome creating $TARFILE"
	tar -cf "$TARFILE" $FILELIST || {
		log "error during tar - disc full?"
		log "START: $STARTDATE -> READY: $( date )"
		exit 1
	}

	echo "scp-ing tarfile $TARFILE to $ARG"
	if scp $SCP_SPECIAL_OPTIONS -P $PORT "$TARFILE" $ARG ; then
		rm "$TARFILE"
	else
		exit 1
	fi
}

echo "iterating over '$( list_networks )' for vds-backup/remove"

COUNT_NETWORK_ALL=0
for _ in $( list_networks ); do COUNT_NETWORK_ALL=$(( COUNT_NETWORK_ALL + 1 )); done

COUNT_NETWORK=0
for NETWORK in $( list_networks ); do {
	COUNT_NETWORK=$(( COUNT_NETWORK + 1 ))
	LIST_PUBIPS="$( list_pubips_from_network "$NETWORK" )"
	for IP in $LIST_PUBIPS; do {
		case " $LIST_IMPORTANT_IPS " in
			*" $IP "*)
				log "dont block/ignoring important IP $IP"
			;;
			*)
				log "blocking access from network $NETWORK ips: $IP"
				iptables -I INPUT -s $IP -p tcp -j REJECT
			;;
		esac
	} done

	FILE="/var/www/networks/$NETWORK/meshrdf/meshrdf.txt"
	[ -e "$FILE" ] && rm "$FILE" && touch "$FILE" && chmod 777 "$FILE"

	TARFILE="/tmp/backup-server-network-$NETWORK-$( uname -n )-$( date +%Y%b%d_%H:%M ).tar"
	echo "network: $NETWORK creating $TARFILE"
	echo "network: $COUNT_NETWORK/$COUNT_NETWORK_ALL"
	tar -cvf "$TARFILE" /var/www/networks/$NETWORK || {
		log "error during tar - disc full?"

		for IP in $LIST_PUBIPS; do {
			log "allowing access from network $NETWORK ips: $IP"
			iptables -D INPUT -s $IP -p tcp -j REJECT
		} done

		ls -l "$TARFILE"
		rm "$TARFILE"
		log "START: $STARTDATE -> READY: $( date )"
		exit 1
	}

	echo "scp-ing tarfile $TARFILE to $ARG - using: scp $SCP_SPECIAL_OPTIONS -P $PORT $TARFILE $ARG"
	echo "network: $COUNT_NETWORK/$COUNT_NETWORK_ALL"
	if scp $SCP_SPECIAL_OPTIONS -P $PORT $TARFILE $ARG; then
		rm "$TARFILE"

		ls -1 /var/www/networks/$NETWORK/vds | while read -r FILE; do {
			case "$FILE" in
				'backup_'*)
					# better: ^"backup_[0-9]*"$
					FILE="/var/www/networks/$NETWORK/vds/$FILE"
					[ -e "$FILE" ] || continue
					echo "removing directory $FILE"
					rm -fR "$FILE"
				;;
			esac
		} done

#		TODO:
#		db_backup.tgz_a8d6a6e4d20aeede356f2dea217d51d2.2013Dec18
#		db_backup.tgz_*.2012*	+ *2013* 	-> nun in compress/rm drinne

		# todo:
		# /var/www/networks/schoeneck/media/map_topology_*

		# generated compressed backups, e.g.:
		# backup_vds_2014Apr09_09:48.tar.lzma
		for FILE in /var/www/networks/$NETWORK/vds/backup_vds_* ; do {
			[ -e "$FILE" ] || continue
			echo "removing $FILE"
			rm "$FILE"
		} done

		for FILE in /var/www/networks/$NETWORK/vds/backup-user-vds-week* ; do {
			[ -e "$FILE" ] || continue
			echo "removing $FILE"
			rm "$FILE"
		} done

		for FILE in /var/www/networks/$NETWORK/vds/backup-user-vds.* ; do {
			[ -e "$FILE" ] || continue
			echo "removing $FILE"
			rm "$FILE"
		} done

		for FILE in /var/www/networks/$NETWORK/media/traffic_* ; do {
			[ -e "$FILE" ] || continue
			echo "removing $FILE"
			rm "$FILE"
		} done
	else
		echo "error during scp - will not delete files but tarfile '$TARFILE'"
		rm "$TARFILE"
		# TODO: unroll ip-blocking
		exit 1
	fi

	for IP in $LIST_PUBIPS; do {
		log "allowing access from network $NETWORK ips: $IP"
		iptables -D INPUT -s $IP -p tcp -j REJECT
	} done
} done

log "START: $STARTDATE -> READY: $( date )"

