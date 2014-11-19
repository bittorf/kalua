#!/bin/sh

# is called when this is the 'weblogin_authserver'
# from any node in the network via netfilter_user_stats_process()

[ -n "$QUERY_STRING" ] && {
	read UPTIME REST <"/proc/uptime"; UPTIME="${UPTIME%.*}"
	echo "UPTIME=${UPTIME}&REMOTE_ADDR=${REMOTE_ADDR}&$QUERY_STRING" >>"/tmp/COLLECT_DATA"
	# processed later via '/usr/sbin/cron.add_collected_userdata_into_db'
}

echo -en "Content-type: text/plain\n\n"

# report which mac's are ok to allow (e.g. DHCP)
ls -1 /tmp/vds_user_* 2>/dev/null | cut -d'_' -f3
echo "OK-UNIXTIME=$( date +%s )"
