#!/bin/sh

TMPDIR='/var/run/kalua'		# is a 'tmpfs'
IPT='/sbin/iptables'

if [ -e "$TMPDIR/server_has_started" ]; then
	:
else
	touch "$TMPDIR/server_has_started"

	sleep 180
	/var/www/scripts/send_sms.sh "liszt28" "0176/24223419" "Server intercity-vpn.de/84.38.67.43 has started"
#	echo 20 >/proc/sys/vm/swappiness

	# generated regulary in 'crontab_example'
	[ -e '/var/www/backup_tmpdir.tar.gz' ] && {
		tar tf '/var/www/backup_tmpdir.tar.gz' && {
			cd / || exit 1
			tar xzf '/var/www/backup_tmpdir.tar.gz'
			cd - || exit 1
		}
	}
fi

file_age_in_sec()
{
	echo $(( $( date +%s ) - $( date +%s -r "$1" ) ))
}

lock()
{
	local option="$1"
	local file="$TMPDIR/LOCKFILE_iptables_whitelister"

	if [ "$option" = 'remove' ]; then
		rm "$file"
	else
		if [ -e "$file" ]; then
			if [ $( file_age_in_sec "$file" ) -gt 3600 ]; then
				log "removing over age lockfile"
				rm -f "$file"
			else
				logger -s "$0: abort, existing '$file'"
				return 1
			fi
		else
			echo "mypid: $$ date: $(date) uptime: $(uptime)" >"$file"
		fi
	fi
}

log()
{
	local history="$TMPDIR/$( basename $0 ).txt"

	logger -s "$0: $1"
	echo "$( date ) $1" >>"$history"
}

uptime_in_seconds()
{
	cut -d'.' -f1 /proc/uptime
}

init_tables_if_virgin()
{
	$IPT -nL INPUT | fgrep -q incoming_ssh || {
		log "virgin iptables, building initial stuff"
		$IPT -N incoming_ssh

		$IPT -I INPUT -m state --state ESTABLISHED -j ACCEPT
		$IPT -I INPUT -p tcp --sport 10022 -j ACCEPT		# from this server to $NETWORK (back)
		$IPT -I INPUT -p tcp --sport 2222 -j ACCEPT		# from this server to $NETWORK (back)
		$IPT -I INPUT -p tcp --sport 22 -j ACCEPT		# from this server to $NETWORK (back)
		$IPT -I INPUT -p tcp --sport 50001 -j ACCEPT		# dito

		$IPT -I INPUT -p tcp --dport 22 -j incoming_ssh
		$IPT -I INPUT -p tcp --dport 2006 -j ACCEPT		# local olsrd/txtinfo
		$IPT -I INPUT -p tcp --dport 5000 -j ACCEPT		# vtun-alt
		$IPT -I INPUT -p udp --dport 5000 -j ACCEPT		# vtun-alt
		$IPT -I INPUT -p tcp --dport 5001 -j ACCEPT		# vtun
		$IPT -I INPUT -p udp --dport 5001 -j ACCEPT		# vtun
		$IPT -I INPUT -p tcp --dport 110 -j ACCEPT		# tinyproxy
		$IPT -I INPUT -p tcp --dport 80 -j ACCEPT
		$IPT -I INPUT -p udp --dport 5353 -j ACCEPT		# DNS questions iodined
		$IPT -I INPUT -p udp --sport 5353 -j ACCEPT		# DNS answers:  iodined
		$IPT -I INPUT -p udp --dport 53 -j ACCEPT		# DNS questions
		$IPT -I INPUT -p udp --sport 53 -j ACCEPT		# DNS answers

		$IPT -I INPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT	# allow own traffic
		$IPT -I INPUT -s 198.23.155.210 -d 127.0.0.1 -j ACCEPT	# IP needed when on 4.v.weimarnetz.de
		$IPT -I INPUT -s 198.23.155.215 -d 127.0.0.1 -j ACCEPT

		$IPT -I INPUT -p icmp -j ACCEPT	
		$IPT -A INPUT -j LOG --log-prefix "notPort80or22or53: "
		$IPT -A INPUT -j REJECT

		$IPT -A incoming_ssh -s intercity-vpn.de -j ACCEPT
		$IPT -A incoming_ssh -s 212.47.248.108 -j ACCEPT	# vpn-scaleway-evernet
		$IPT -A incoming_ssh -s 130.255.188.37 -j ACCEPT	# evo2/nanoVZ
		$IPT -A incoming_ssh -s 198.23.155.215 -j ACCEPT	# chicagoVPS2
		$IPT -A incoming_ssh -s 198.23.155.210 -j ACCEPT	# chicagoVPS
		$IPT -A incoming_ssh -s 172.30.0.0/16 -j ACCEPT		# iodine
		$IPT -A incoming_ssh -s 77.87.48.19 -j ACCEPT		# weimarnetz.de
		$IPT -A incoming_ssh -s 178.77.78.244 -j ACCEPT		# 178.is
		$IPT -A incoming_ssh -s 128.93.132.10 -j ACCEPT		# gnu/cc-farm
		$IPT -A incoming_ssh -s 141.54.1.2 -j ACCEPT		# ping01
		$IPT -A incoming_ssh -s 77.87.48.22 -j ACCEPT		# bb.weimarnetz.de
		$IPT -A incoming_ssh -j LOG --log-prefix "unthrusted SSH: "
		$IPT -A incoming_ssh -j REJECT
	}
}

list_names_of_monitored_networks()
{
	ls -1 /var/www/networks/
#	find /var/www/networks/ -type f -name 'pubip.txt' | cut -d'/' -f5
}

whitelist_ip_already_known()
{
	local ip="$1"

	$IPT -nL incoming_ssh | fgrep -q " $ip "
}

whitelist_learn_ip()
{
	local ip="$1"
	local network="$2"

	$IPT -nL incoming_ssh | fgrep -q "$network" || {
		log "new network detected: $network"
		$IPT -N incoming_ssh_$network
		$IPT -I incoming_ssh_$network -j ACCEPT
	}

	log "now thrusting ip $ip from network $network"
	$IPT -I incoming_ssh -s $ip -j incoming_ssh_$network
}

loop_networks()
{
	local pubip network file

	for network in $( list_names_of_monitored_networks ); do {
		for file in $( find 2>/dev/null "/var/www/networks/$network/meshrdf/recent" -type f -name '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]' -mtime -2 ); do {
			command . "$file" && pubip="$PUBIP_REAL"

#			pubip=
#			read pubip </var/www/networks/$network/pubip.txt

			[ -n "$pubip" ] && {
				if whitelist_ip_already_known "$pubip" "$network"; then
					:
					# log "network $network: $pubip [OLD]"
				else
					whitelist_learn_ip "$pubip" "$network"
				fi
			}
		} done
	} done
}

case "$1" in
	start)
		lock || exit 1

		init_tables_if_virgin
		loop_networks

		lock remove
	;;
	stop)
		lock || exit 1

		$IPT -F
		$IPT -X

		lock remove
	;;
	restart)
		$0 stop
		$0 start
	;;
	*)
		echo "Usage: $0 (start|stop|restart)"
	;;
esac
