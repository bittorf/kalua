power_and_freq_to_regdomain()
{
	local needed_freq="$1"		# e.g. 2450
	local needed_power="$2"		# e.g. 28	// optional | EIRP [dbm]

	local line country freq1 freq2 channel_width max_ant_db mac_eirp
	local url_regdb="http://git.kernel.org/?p=linux/kernel/git/linville/wireless-regdb.git;a=blob_plain;f=db.txt;hb=HEAD"
	local url_regdb="http://intercity-vpn.de/regdb/db.txt"

	wget -qO - "$url_regdb" |
	 while read line; do {
		case "$line" in							# country AU:
			"country "[A-Z]*)					# 	(2402 - 2482 @ 40), (N/A, 20)
				country="${line#* }"	# all after space	#	(5170 - 5250 @ 40), (3, 23)
				country="${country%:*}"	# all before :		#	(5250 - 5330 @ 40), (3, 23), DFS
			;;							#	(5735 - 5835 @ 40), (3, 30)
			"")							#
				country=					# country XY:
			;;							#	(5150 - 5250 @ 40), (N/A, 200 mW), NO-OUTDOOR
			*)
				[ -n "$country" ] && {
					freq1=; freq2=; channel_width=; max_ant_db=; mac_eirp=
					eval "$( echo $line | sed -n 's/^.*(\([0-9]*\) - \([0-9]*\) @ \([0-9]*\)), (\(.*\), \([0-9]*\)).*/freq1=\1;freq2=\2;channel_width=\3;max_ant_db=\4;max_eirp=\5/p' )"

					[ -n "$freq1" ] && {
						[ $needed_freq -le $freq2 -a $needed_freq -ge $freq1 ] && {
							if [ -n "$needed_power" ]; then
								[ $max_eirp -ge $needed_power ] && {
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
	} done
}

power_and_freq_to_regdomain "$1" "$2"
