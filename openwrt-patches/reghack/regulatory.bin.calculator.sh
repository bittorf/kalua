#!/bin/sh

power_and_freq_to_regdomain()
{
	local needed_freq="$1"		# e.g. 2450
	local needed_power="$2"		# e.g. 28	// optional | EIRP [dbm]

	local line country freq1 freq2 channel_width max_ant_db mac_eirp
	local url_regdb='http://git.kernel.org/cgit/linux/kernel/git/sforshee/wireless-regdb.git/plain/db.txt'
	local cache="/tmp/regdb.txt"

	if [ -s "$cache" ]; then
		echo "[OK] using '$cache'"
	else
		wget -O "$cache" "$url_regdb"
	fi

	while read -r line; do {
		case "$line" in							# country AU:
			'country '[A-Z]*)					# 	(2402 - 2482 @ 40), (N/A, 20)
				country="${line#* }"	# all after space	#	(5170 - 5250 @ 40), (3, 23)
				country="${country%:*}"	# all before :		#	(5250 - 5330 @ 40), (3, 23), DFS
			;;							#	(5735 - 5835 @ 40), (3, 30)
			'')							#
				country=					# country XY:
			;;							#	(5150 - 5250 @ 40), (N/A, 200 mW), NO-OUTDOOR
			*)							#
										# country JP: DFS-JP
				[ -n "$country" ] && {				#       (4910 - 4990 @ 40), (23)
					case "$line" in
						'#'*)
							continue
						;;
					esac

					freq1=; freq2=; channel_width=; max_ant_db=; mac_eirp=
					# (5490 - 5710 @ 160), (27), DFS
					# (5250.000 - 5330.000 @ 80.000), (23.00), DFS, AUTO-BW
					set -- $line

					freq1=$1							# (5250.000
					freq1="$( echo "$freq1" | cut -d'(' -f2 | cut -d'.' -f1 )"	# 5250

					freq2=$3							# 5330.000
					freq2="$( echo "$freq2" | cut -d'.' -f1 )"			# 5330

					channel_width=$5								# 80.000),
					channel_width="$( echo "$channel_width" | cut -d')' -f1 | cut -d'.' -f2 )"	# 80

					max_ant_db=$6										# (23.00),
					max_ant_db="$( echo "$max_ant_db" | cut -d'(' -f2 | cut -d')' -f1 | cut -d'.' -f1 )"	# 23

					mac_eirp=$*	# DFS, AUTO-BW - FIXME!

					[ -n "$freq1" ] && {
						[ $needed_freq -le $freq2 -a $needed_freq -ge $freq1 ] && {
							if [ -n "$needed_power" ]; then
								[ $max_ant_db -ge $needed_power ] && {
									echo "$country $line"
								}
							else
								echo "$country $line"
							fi
						}
					}
				}
			;;
		esac
	} done <"$cache"
}

if [ -z "$1" ]; then
	echo "Usage: $0 <freq> <power>"
	echo " e.g.: $0 4915"
	echo " e.g.: $0 5180 21"
	echo " e.g.: $0 6425"

	false
else
	power_and_freq_to_regdomain "$1" "$2"
fi
