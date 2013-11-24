#!/bin/sh
# sourced from /sbin/hotplug-call

case "$ACTION" in
	'pressed')
		read UP REST </proc/uptime
		echo "${UP%.*}${UP#*.}" >'/tmp/BUTTON'
	;;
	'released')
		read UP REST </proc/uptime
		read START <'/tmp/BUTTON'

		END="${UP%.*}${UP#*.}"
		DIFF=$(( $END - $START ))

		logger "BUTTON released: $DIFF millisec"
	;;
esac
