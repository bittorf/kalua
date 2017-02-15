#!/bin/sh

# for every kernel-version, we write a file with the unixtime and
# changelog which can later easily retrieved via HTTP and searched, e.g.:
# grep -i JFFS2: /var/www/kernel_history/*changelog.txt
#
# root@box:~# ls -1 /var/www/kernel_history/3.7.10*
# /var/www/kernel_history/3.7.10
# /var/www/kernel_history/3.7.10-changelog.txt
#
# root@box:~# cat /var/www/kernel_history/3.7.10
# 1361953324

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

for MAIN_VERSION in 'v2.4' 'v2.5' 'v2.6' 'v3.0' 'v3.x' 'v4.x'; do {
	URL="https://www.kernel.org/pub/linux/kernel/$MAIN_VERSION"
	mkdir -p "$DIR"
	logger -s "fetching '$URL' and filling '$DIR'"

	# FIXME! '2.6' has not much changelogs - it does not work...

	wget --no-check-certificate -O - "$URL" | while read -r LINE; do {
		# e.g.
		# <a href="ChangeLog-3.0.12">ChangeLog-3.0.12</a>
		# <a href="ChangeLog-3.0.12.sign">ChangeLog-3.0.12.sign</a>
		# <a href="ChangeLog-4.4.47.sign">ChangeLog-4.4.47.sign</a>   04-Feb-2017 08:55  833

		oldIFS="$IFS"; IFS='"'; set -- $LINE; IFS="$oldIFS"
		LINK="$2"

		case "$LINK" in
			'ChangeLog'*)
				case "$LINK" in
					*'.sign')
					;;
					*)
						# ChangeLog-3.0.12 -> 3.0.12
						FILE="$LINK"
						VERSION="$( echo "$LINK" | cut -d'-' -f2 )"

						[ -e "$DIR/${VERSION}-changelog.txt" ] || {
							logger -s "downloading changelog: $FILE"
							wget -qO "$DIR/${VERSION}-changelog.txt" "$URL/$FILE"
						}

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
						wget -qO - "$URL/$LINK" >"$DIR/tempfile"
						while read -r LINE; do {
							case "$LINE" in
								'Date:'*)
									set -- $LINE; shift
									# Fri Dec 9 08:53:50 2011 -0800
									DATE="$*"
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
						} done <"$DIR/tempfile"
						rm "$DIR/tempfile"

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
