#!/bin/sh

ACTION="$1"
OPTION="$2"
OPTION2="$3"
OPTION3="$4"

show_help()
{
	local me="$( basename $0 )"

	cat <<EOF
Usage: 	$me <action> <option1> <option2> <option3>

e.g.	$me ask_me_everything_step_by_step

or:	$me gitpull
	$me show_known_hardware_models
	$me set_build_config <hardware>				# e.g. "Linksys WRT54G:GS:GL"
	$me applymystuff <profile> <subprofile> <nodenumber>	# e.g. "ffweimar" "adhoc" "42"
	$me make
	$me upload <destination_keywords>			# e.g. labor | ffweimar ap 23
EOF
}

[ -z "$ACTION" ] && {
	show_help
	exit 1
}

log()
{
	logger -s "$1"
}

get_arch()
{
	sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\(.*\)"/\1/p' .config		# brcm47xx|ar71xx|???
}

show_known_hardware_models()
{
	local dir="$( dirname $0 )/../openwrt-config/hardware"
	local filename

	find "$dir/"* -type d | while read filename; do {
		basename "$filename"
	} done
}

ask_me_everything_step_by_step()
{
	:
}

bwserver_ip()
{
	local ip

	get_ip()
	{
		ip="$( wget -qO - "http://intercity-vpn.de/networks/liszt28/pubip.txt" )"
	}

	while [ -z "$ip" ]; do {
		get_ip && {
			echo $ip
			return
		}

		log "fetching bwserver_ip"
		sleep 1
	} done
}

apply_tarball_regdb_and_applyprofile()
{
	local installation="$1"		# elephant
	local sub_profile="$2"		# adhoc
	local node="$3"			# 83
	local file

	local tarball="http://intercity-vpn.de/firmware/ar71xx/images/testing/tarball.tgz"
	local url_regdb="http://intercity-vpn.de/files/regulatory.bin"

	local pwdold="$( pwd )"
	cd package/base-files/files/

	wget -qO "tarball.tgz" "$tarball"				# tarball
	tar xzf "tarball.tgz"
	rm "tarball.tgz"

	cd etc/init.d
	wget -qO apply_profile.regulatory.bin "$url_regdb"		# regDB

	local ip_buero="$( bwserver_ip )"
	local remote_dir="Desktop/bittorf_wireless/programmierung"
	local pre="-P 222 bastian@$ip_buero"

	scp $pre:$remote_dir/etc-initd-apply_profile apply_profile
	scp $pre:$remote_dir/apply_profile-all.sh apply_profile.code

	case "$installation" in
		"")
			log "nothing to additionally apply -> generic image"
		;;
		qsoft)
			remote_dir="Desktop/bittorf_wireless/kunden/qsoft/config"
			scp $pre:$remote_dir/qsoft.csv apply_profile.csv
			scp $pre:$remote_dir/apply_config.qsoft.sh apply_profile.code

			[ "$node" ] && {
				file="/etc/init.d/apply_profile.csv"
				sed -i "s|^NODE=\"\$1\"|NODE=${node}|" apply_profile.code
				sed -i "s|^FILE=\"\$2\"|FILE=${file}|" apply_profile.code
				head -n12 apply_profile.code | tail -n4
			}
		;;
		*)
			[ "$node" ] && {
				sed -i "s/^#SIM_ARG1=/SIM_ARG1=$installation    #/" apply_profile.code
				sed -i "s/^#SIM_ARG2=/SIM_ARG2=$sub_profile    #/" apply_profile.code
				sed -i "s/^#SIM_ARG3=/SIM_ARG3=$node    #/" apply_profile.code

				local startline
				startline="$( grep -n ^"# enforcing a profile" apply_profile.code | cut -d':' -f1 )"
				startline="$(( $startline + 9 ))"
				head -n $startline apply_profile.code | tail -n 13
			}
		;;
	esac

	cd "$pwdold"

	case "$( get_arch )" in
		ar71xx)
			case "$installation" in
				rehungen*|liszt28*)
					scp $pre:$remote_dir/openwrt-patches/999-ath9k-register-reading.patch package/mac80211/patches
				;;
				*)
					[ -e "package/mac80211/patches/999-ath9k-register-reading.patch" ] && {
						rm "package/mac80211/patches/999-ath9k-register-reading.patch"
					}
				;;
			esac
		;;
		*)
			[ -e "package/mac80211/patches/999-ath9k-register-reading.patch" ] && {
				rm "package/mac80211/patches/999-ath9k-register-reading.patch"
			}
		;;
	esac
}

case "$ACTION" in
	applymystuff)
		apply_tarball_regdb_and_applyprofile "$OPTION" "$OPTION2" "$OPTION3"
	;;
	make)
		T1=$(date)
		make
		echo $T1
		date
	;;
	gitpull)
		cd ../packages
		git pull
		cd ../openwrt
		git pull
	;;
	upload)
		SERVERPATH="root@intercity-vpn.de:/var/www/firmware/$( get_arch )/images/testing/"	
		[ -n "$OPTION2" ] || SERVERPATH="$SERVERPATH/$OPTION"					# liszt28

		FILEINFO="${OPTION}${OPTION2}${OPTION3}"						# liszt28ap4
		[ -n "$FILEINFO" ] && FILEINFO="$FILEINFO-"

		case "$( get_arch )" in
			ar71xx)
				if   grep -q ^"CONFIG_TARGET_ar71xx_generic_UBNT=y" .config ; then
					LIST_FILES="            openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-factory.bin"
					LIST_FILES="$LIST_FILES openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-sysupgrade.bin"
				elif grep -q ^"CONFIG_TARGET_ar71xx_generic_TLWR1043NDV1=y" .config ; then
					LIST_FILES="            openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-factory.bin"
					LIST_FILES="$LIST_FILES openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin"
				fi
			;;
			brcm47xx)

				# check for
				# CONFIG_TARGET_brcm47xx_Broadcom-b43=y		@ .config
				# CONFIG_TARGET_brcm47xx_Atheros-ath5k=y

				LIST_FILES="openwrt-brcm47xx-squashfs.trx openwrt-wrt54g-squashfs.bin"
			;;
		esac

		for FILE in $LIST_FILES; do {
			log "scp-ing file '$FILE' -> '${FILEINFO}${FILE}'"
			scp bin/$( get_arch )/$FILE "$SERVERPATH/${FILEINFO}${FILE}"
			WGET_URL="http://intercity-vpn.de/firmware/$( get_arch )/images/testing/${FILEINFO}${FILE}"
			log "download with: wget -O ${FILEINFO}.bin '$WGET_URL'"
		} done
	;;
	update)
		FILE="openwrt-firmware-bauen.sh"
		scp -P 222 bastian@$( bwserver_ip ):/home/bastian/Desktop/bittorf_wireless/programmierung/$FILE /tmp
		log "mv /tmp/$FILE to ."
		chmod +x /tmp/$FILE
		mv /tmp/$FILE .
		log "[OK]"
	;;
	*)
		$ACTION
	;;
esac

# tools:
#
# for NN in $( seq 182 228 ); do {
# 	./openwrt-firmware-bauen.sh applymystuff qsoft any "$NN"
#	./openwrt-firmware-bauen.sh make
#	./openwrt-firmware-bauen.sh upload "qsoft${NN}"
# } done
#
# ./openwrt-firmware-bauen.sh applymystuff liszt28 ap 4
#
