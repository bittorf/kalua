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
		eval $( _http query_string_sanitize "$0:roaming_add" )

		# see: net_roaming_report_new()
		echo "$mac $ip $expires" >>'/tmp/roaming'
		echo 'OK'
	;;
	*'roaming_getlist'*)
		# simulate 'tac'
		grep -n '' '/tmp/roaming' | sort -rn | cut -d: -f2-
		echo 'OK'
	;;
	*'roaming_querymac'*)
		. /tmp/loader
		eval $( _http query_string_sanitize "$0:roaming_querymac" )

		# format: mac ip expires - see: net_roaming_report_new() - searched newest entires first = 'tac'
		if LINE="$( grep -sn '' '/tmp/roaming' | sort -rn | cut -d: -f2- | grep ^"$mac" )"; then
			set -- $LINE
			echo $2
		else
			_log do roaming_querymac daemon info "no entry for $mac ($REMOTE_ADDR asked)"
		fi
	;;
	*)
		# processed later via '/usr/sbin/cron.add_collected_userdata_into_db'
		read UPTIME REST <'/proc/uptime'
		echo "UPTIME=${UPTIME%.*}&REMOTE_ADDR=${REMOTE_ADDR}&$QUERY_STRING" >>'/tmp/COLLECT_DATA'

		# while we have a conversation anyway,
		# report which mac's are OK to allow (e.g. DHCP)
		for FILE in /tmp/vds_user_*; do {
			FILE="${FILE#*user_}"

			case "$FILE" in
				'*')
				;;
				*)
					echo "$FILE"
				;;
			esac
		} done

		echo "OK-UNIXTIME=$( date +%s )"
	;;
esac
