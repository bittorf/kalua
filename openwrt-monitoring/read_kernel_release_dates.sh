#!/bin/sh

DIR='/var/www/kernel_history'

monthname2number()
{
	case "$1" in
		Jan|jan) echo "01" ;;
		Feb|feb) echo "02" ;;
		Mar|mar) echo "03" ;;
		Apr|apr) echo "04" ;;
		May|may) echo "05" ;;
		Jun|jun) echo "06" ;;
		Jul|jul) echo "07" ;;
		Aug|aug) echo "08" ;;
		Sep|sep) echo "09" ;;
		Oct|oct) echo "10" ;;
		Nov|nov) echo "11" ;;
		Dec|dec) echo "12" ;;
	esac
}

for MAIN_VERSION in 'v2.4' 'v2.5' 'v2.6' 'v3.0' 'v3.x'; do {
	URL="https://www.kernel.org/pub/linux/kernel/$MAIN_VERSION"
	mkdir -p "$DIR"
	logger -s "fetching '$URL' and filling '$DIR'"

	# FIXME! '2.6' has not much changelogs - it does not work...

	wget -qO - "$URL" | while read LINE; do {
		# e.g.
		# <a href="ChangeLog-3.0.12">ChangeLog-3.0.12</a>
		# <a href="ChangeLog-3.0.12.sign">ChangeLog-3.0.12.sign</a>

		oldIFS="$IFS"; IFS='"'; set -- $LINE; IFS="$oldIFS"
		LINK="$2"

		case "$LINK" in
			'ChangeLog'*)
				case "$LINK" in
					*'.sign')
					;;
					*)
						# ChangeLog-3.0.12 -> 3.0.12
						VERSION="$( echo "$LINK" | cut -d'-' -f2 )"

						if [ -e "$DIR/$VERSION" ]; then
#							logger -s "kernel $VERSION already known"
							continue
						else
							set -- $LINE
							# 22-Feb-2001 01:02
							FILEDATE="$3 $4"
							logger -s "new kernel: $VERSION filedate: $FILEDATE dir: $DIR"
						fi

						DATE_WELLFORMED=
						wget -qO - "$URL/$LINK" | while read LINE; do {
							case "$LINE" in
								'Date:'*)
									set -- $LINE; shift
									# Fri Dec 9 08:53:50 2011 -0800
									DATE="$@"
									set -- $DATE

									# year-month-day hour:min:sec
									# 2011-08-01 07:05:01
									DATE_WELLFORMED="$5-$( monthname2number "$2" )-$( test ${#3} -eq 1 && echo '0' )$3 $4"
									if UNIXTIME="$( date --date "$DATE_WELLFORMED" +%s )"; then
										echo "$UNIXTIME" >"$DIR/$VERSION"
									else
										logger -s "ERROR - date: '$DATE' wellformed: '$DATE_WELLFORMED'"
									fi

									break
								;;
							esac
						} done

						[ -z "$DATE_WELLFORMED" ] && {
							logger -s "changelog without good date - taking filedate: $FILEDATE"
							# source: 22-Feb-2001 01:02
							# needed: 2001-02-22 01:02:00
							YEAR="$(  echo "$FILEDATE" | cut -d'-' -f3 | cut -d' ' -f1 )"
							MONTH="$( echo "$FILEDATE" | cut -d'-' -f2 )"
							DAY="$(   echo "$FILEDATE" | cut -d'-' -f1 )"
							TIME="$(  echo "$FILEDATE" | cut -d' ' -f2 )"

							DATE_WELLFORMED="$YEAR-$( monthname2number "$MONTH" )-$DAY $TIME:00"
							if UNIXTIME="$( date --date "$DATE_WELLFORMED" +%s )"; then
								echo "$UNIXTIME" >"$DIR/$VERSION"
							else
								logger -s "ERROR - date: '$DATE' wellformed: '$DATE_WELLFORMED'"
							fi
						}
					;;
				esac
			;;
		esac
	} done

} done
