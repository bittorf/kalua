#!/bin/sh

# this script is called when this is the 'weblogin_authserver'
# from any node in the network via netfilter_user_stats_process()
# or from net_roaming_report_new()

echo -en "Content-type: text/plain\n\n"

case "$QUERY_STRING" in
	'')
		echo 'OK - empty QUERY'
	;;
	*'roaming_add'*)
		. /tmp/loader
		eval $( _http query_string_sanitize )

		# see: net_roaming_report_new()
		echo "$mac $ip $expires" >>'/tmp/roaming'
		echo 'OK'
	;;
	*'roaming_getlist'*)
		cat '/tmp/roaming'
		echo 'OK'
	;;
	*'roaming_querymac'*)
		. /tmp/loader
		eval $( _http query_string_sanitize )

		# format: mac ip expires - see: net_roaming_report_new()
		if LINE="$( grep -s ^"$mac" '/tmp/roaming' )"; then
			set -- $LINE
			echo $2
		else
			_log do roaming_querymac daemon info "no entry for $mac"
		fi
	;;
	*)
		# processed later via '/usr/sbin/cron.add_collected_userdata_into_db'
		read UPTIME REST <'/proc/uptime'
		echo "UPTIME=${UPTIME%.*}&REMOTE_ADDR=${REMOTE_ADDR}&$QUERY_STRING" >>'/tmp/COLLECT_DATA'

		# while we have a conversation anyway,
		# report which mac's are ok to allow (e.g. DHCP)
		ls -1 /tmp/vds_user_* 2>/dev/null | cut -d'_' -f3
		echo "OK-UNIXTIME=$( date +%s )"
	;;
esac
