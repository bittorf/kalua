#!/bin/sh

check_wifi_phy()	# watch if value-change of received_multicast_frames > X% of moving average of last 15 values
{
	local phy="${1:-phy0}"
	local uptime_now="$2"	# seconds/integer
	local file_source="/sys/kernel/debug/ieee80211/$phy/statistics/multicast_received_frame_count"
	local file_old="/tmp/incoming_frames.$phy"
	local file_window="/tmp/incoming_frames.$phy.window"
	local border=16		# change in percent
	local frames_old=0 uptime_old=0 valid=1 percentual_change
	local frames_now frames_diff frames_average frames_average_overall uptime_now interval line value valid val1 val2

	[ -z "$uptime_now" ] && {
		read uptime_now interval </proc/uptime
		uptime_now="${uptime_now%.*}"
	}

	read frames_old uptime_old <"$file_old" || echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >"$file_window"	# prefill
	read frames_now <"$file_source"
	echo "$frames_now $uptime_now" >"$file_old"

	interval=$(( $uptime_now - $uptime_old ))
	frames_diff=$(( $frames_now - $frames_old ))
	frames_average=$(( $frames_diff / $interval ))

	while read line; do {
		if [ -n "$value" ]; then
			test $line -eq 0 || {
				value=$(( $value + $line ))
				valid=$(( $valid + 1 ))
			}
			echo "$line"
		else
			value="$line"			# omit first line
		fi
	} done <"$file_window" >"$file_window.tmp"
	echo "$frames_average" >>"$file_window.tmp"	# append recent value
	mv "$file_window.tmp" "$file_window"

	[ $valid -gt 0 ] && {
		frames_average_overall=$(( $value / $valid ))
		val1=$frames_average
		val2=$frames_average_overall

		if [ $val1 -eq $val2 ]; then
			percentual_change=0
		else
			[ $val1 -eq 0 ] && val1=1
			percentual_change=$(( (($val2 - $val1) * 100) / $val1 ))
		fi
	}

	# global export
	REST="interval: $interval f: $frames_now fold: $frames_old f_avg: $frames_average f_avg_overall: $frames_average_overall pchange: $percentual_change"
	logger -s "$REST"

	test $percentual_change -lt -$border && return 1
	test $percentual_change -gt $border && return 1

	return 0
}

check_wifi_phy "phy0" "${UP%.*}" || {
	. /tmp/loader
	_log do "check_wifi_phy" daemon alert "$REST"
}
