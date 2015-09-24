#!/bin/sh
# sourced from /sbin/hotplug-call
# or call via:
# BUTTON=wps; ACTION=released; . /etc/hotplug.d/button/events.sh

# also must take care of '/etc/rc.button/reset'
[ "$BUTTON" = 'reset' ] && BUTTON='wps'

case "${BUTTON}-${ACTION}" in
	# wps = WiFi Protected Setup: http://wiki.openwrt.org/doc/uci/wireless#wps.options
	'wps-pressed')
		read UP REST </proc/uptime
		echo "${UP%.*}${UP#*.}" >'/tmp/BUTTON'
	;;
	'wps-released')
		read UP REST </proc/uptime
		read START 2>/dev/null <'/tmp/BUTTON' || START="${UP%.*}"

		END="${UP%.*}${UP#*.}"
		DIFF=$(( END - START ))

		# FIXME! DIFF = 1000 -> 10 seconds
		logger -s -- "$0: button '$BUTTON' released after $DIFF millisec"

		# works with e.g.
		# Alesis M1 Active 320 USB = 08bb:29b0 = Texas Instruments PCM2900B Audio CODEC:
		# PE-5819-919 auvisio ext. USB-Soundkarte "Virtual 7.1" = 0d8c:000c = C-Media Electronics, Inc. Audio Adapter
		next_radio()
		{
			route -n | grep -q ^"0\.0\.0\.0" || return 0

			local file="/tmp/audioplayer.sh"
			local dummy url
			local i=1
			local url1='soma.fm secret-agent http://mp3.somafm.com:443'
			local url2='soma.fm space-station http://sfstream1.somafm.com:2020'
			local url3='soma.fm xmasinfrisko http://sfstream1.somafm.com:2100'
			local url4='soma.fm indiepop http://sfstream1.somafm.com:8090'
			local url5='mdr figaro http://avw.mdr.de/livestreams/mdr_figaro_live_128.m3u'
			local url6='radio-blau main http://www.radioblau.de/stream/radioblau.m3u'
			local url7='apollo-radio main http://stream.apolloradio.de/APOLLO/mp3.m3u'
			local url8='radio-lotte main http://www.radio-lotte.de/stream/radiolotte.m3u'
			local url9='FM4 main http://mp3stream1.apasf.apa.at:8000'

			if [ -e "$file" ]; then
				read dummy i <"$file"
				i=$(( i + 1 ))

				killall madplay
				# play a jingle? -> http://ctrlq.org/listen/
			else
				[ -e '/tmp/audioplayer.dev' ] || return
			fi

			# file generated during cron-startup
			read DSPDEV <'/tmp/audioplayer.dev'

			case "$i" in
				2|3|4|5|6|7|8|9)
					eval url="\$url$i"
				;;
				*)
					url="$url1"
					i=1
				;;
			esac

			logger -s -- "$0: audioplayer: station: $url"
			url="$( echo $url | cut -d' ' -f3 )"
			case "$url" in
				*'.m3u'|*.'M3U')
					url="$( wget -qO - "$url" | grep -v ^'#' | head -n1 )"
				;;
			esac

			logger -s -- "$0: audiplayer: i: $i - url: $url"
			echo  >"$file" "# $i"
			# rmmod because of https://dev.openwrt.org/ticket/13392
			echo >>"$file" "( wget --user-agent 'AUDIOPLAYER' --quiet -O - '$url' | madplay --output=$DSPDEV --quiet - || { rmmod snd_usb_audio; modprobe snd_usb_audio; } ) &"

			chmod +x "$file"
			exec "$file"
		}

		if PID="$( pidof madplay )" ; then
			if [ $DIFF -ge 100 ]; then	# long pressed
				rm '/tmp/audioplayer.sh'
				kill $PID
			else
				next_radio
			fi
		else
			next_radio
		fi

		. /tmp/loader
		_weblogin authserver_message "button_pressed.$LANADR.$HOSTNAME.$DIFF.msec"

		[ $DIFF -gt 300 ] && {
			_log do firmware_button daemon info "button_pressed.$LANADR.$HOSTNAME.$DIFF.msec"

			[ $DIFF -gt 1000 ] && {
				touch '/coredump/testdump.core'		# FIXME! see system_adjust_coredump()
				_watch coredump
			}

			PID="$( uci -q get system.@monitoring[0].button_smstext )" && {
				for END in $( uci -q get system.@monitoring[0].button_phone ); do {
					USERNAME="$( uci -q get sms.@sms[0].username )"
					PASSWORD="$( uci -q get sms.@sms[0].password )"
					_sms send "$END" "$PID" '' "$USERNAME" "$PASSWORD"
				} done
			}
		}
	;;
	*)
		logger -s -- "$0: button '$BUTTON' action: '$ACTION' ignoring args: $*"
	;;
esac
