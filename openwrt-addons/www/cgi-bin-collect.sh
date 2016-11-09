#!/bin/sh
. /tmp/loader

# this script is called when this is the 'weblogin_authserver'
# from any node in the network via netfilter_user_stats_process()
# or from net_roaming_report_new()

_http header_mimetype_output 'text/plain'

tac_roaming()
{
	grep -sn '' "$TMPDIR/roaming" | sort -rn | cut -d: -f2-
}

case "$QUERY_STRING" in
	*'roaming_mac_action'*)
		mode=;unixtime=;mac=;ip=;freq=;signal=;node=;hostname=
		eval $( _http query_string_sanitize "$0:roaming_mac_action" )

		# sortable via timestamp
		timestamp="$( date '+%X' -d @$unixtime )"
		ip="${ip:-no_ip}"
		signal="${signal:-  ?}"
		signal="$( printf '%3s' "$signal" )"
		echo "$unixtime/$timestamp - $mode: $mac/$ip/$freq Mhz/$signal dBm @ $node/$hostname" >>"$TMPDIR/roaming_debug"

		echo 'OK'
	;;
	*'roaming_add'*)
		mac=;ip=;expires=
		eval $( _http query_string_sanitize "$0:roaming_add" )

		# see: net_roaming_report_new()
		echo "$mac $ip $expires" >>"$TMPDIR/roaming"
		echo 'OK'
	;;
	*'roaming_getlist'*)
		tac_roaming
		echo 'OK'
	;;
	*'roaming_querymac'*)
		eval $( _http query_string_sanitize "$0:roaming_querymac" )

		# format: mac ip expires - see: net_roaming_report_new() - searched newest entires first = 'tac'
		if LINE="$( tac_roaming | grep ^"$mac" )"; then
			explode $LINE
			echo $2
		else
			_log it roaming_querymac daemon info "no entry for $mac ($REMOTE_ADDR asked)"
		fi
	;;
	*)
		# processed later via '/usr/sbin/cron.add_collected_userdata_into_db'
		read -r UPTIME _ <'/proc/uptime'
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
