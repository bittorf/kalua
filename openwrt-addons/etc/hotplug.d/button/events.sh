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

		logger "$0: button released after $DIFF millisec"

		next_radio()
		{
			local file="/tmp/audioplayer.sh"
			local dummy url
			local i=1
			local url1='soma.fm space-station http://sfstream1.somafm.com:2020'
			local url2='soma.fm secret-agent http://mp3.somafm.com:443'
			local url3='soma.fm xmasinfrisko http://sfstream1.somafm.com:2100'
			local url4='soma.fm indiepop http://sfstream1.somafm.com:8090'
			local url5='mdr figaro http://avw.mdr.de/livestreams/mdr_figaro_live_128.m3u'
			local url6='radio-blau main http://www.radioblau.de/stream/radioblau.m3u'

			if [ -e "$file" ]; then
				read dummy i <"$file"
				i=$(( $i + 1 ))

				killall madplay
				# play a jingle? -> http://ctrlq.org/listen/
			else
				which madplay >/dev/null || return
			fi

			case "$i" in
				2|3|4|5|6)
					eval url="\$url$i"
				;;
				*)
					url="$url1"
					i=1
				;;
			esac

			logger "station: $url"
			url="$( echo $url | cut -d' ' -f3 )"
			case "$url" in
				*'.m3u'|*.'M3U')
					url="$( wget -qO - "$url" | grep -v ^'#' | head -n1 )"
				;;
			esac

			logger "i: $i - url: $url"
			echo  >"$file" "# $i"
			echo >>"$file" "( wget -qO - '$url' | madplay -v - ) &"
			chmod +x "$file"

			exec "$file"
		}

		if PID="$( pidof madplay )" ; then
			if [ $DIFF -ge 100 ]; then	# long pressed
				kill $PID
			else
				next_radio
			fi
		else
			next_radio
		fi
	;;
esac
