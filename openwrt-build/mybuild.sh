#!/bin/sh

ACTION="$1"
OPTION="$2"
OPTION2="$3"
OPTION3="$4"

show_help()
{
	local me="$0"

	cat <<EOF
Usage:	$me gitpull
	$me config2git
	$me select_hardware_model
	$me set_build_openwrtconfig
	$me set_build_kernelconfig
	$me set_build <standard|nopppoe>
	$me applymystuff <profile> <subprofile> <nodenumber>	# e.g. "ffweimar" "adhoc" "42"
	$me make <option>
	$me build_kalua_update_tarball [full]

Hint:   for building multiple config-enforced images use e.g.:
	APP="$0"
	for I in \$(seq 2 70); do for MODE in adhoc ap; do \$APP applymystuff "ffweimar" \$MODE \$I; \$APP make; done; done

EOF
}

case "$ACTION" in
	"")
		show_help
		exit 1
	;;
	make)
		ACTION="mymake"
	;;
esac

[ -d kalua ] || {
	echo "please make sure, that your working directory is in the openwrt-base dir"
	echo "i want to see the directorys 'package', 'scripts' and 'kalua'"
	exit 1
}

log()
{
	logger -s "$1"
}

get_arch()
{
	sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\(.*\)"/\1/p' .config		# brcm47xx|ar71xx|atheros|???
}

set_build()
{
	local mode="$1"			# e.g. mini|standard|full
	local config=".config"
	local line symbol file

	file="kalua/openwrt-config/config_${mode}.txt"
	[ -e "$file" ] || {
		log "mode '$mode' not implemented yet"
		return 1
	}

	while read line; do {
		log "apply symbol: $line"

		case "$line" in
			*"=y")
				symbol="$( echo "$line" | sed -n 's/\(^.*\)=y/\1/p' )"
				# if its marked as NO, change it to YES
				sed -i "s/# ${symbol} is not set/${symbol}=y/" "$config"
			;;
			*" is not set")
				symbol="$( echo "$line" | sed -n 's/\(^.*\) is not set/\1/p' )"
				# if its marked as YES, change it to NO
				sed -i "s/${symbol}=y/# ${symbol} is not set/" "$config"
			;;
		esac
	} done <"$file"
}

filesize()
{
	local file="$1"
	local option="$2"

	case "$option" in
		flashblocks)
			local blocks bytes overlap percent blocksize hardware
			read hardware <KALUA_HARDWARE

			case "$hardware" in
				*)
					blocksize="65536"
				;;
			esac

			bytes="$( stat --format=%s "$file" )"
			blocks="$(( $bytes / $blocksize ))"
			overlap="$(( $bytes % $blocksize ))"
			percent="$(( $overlap * 100 / $blocksize ))"

			if [ "$overlap" = "0" ]; then
				echo "$blocks flash/eraseblocks@${blocksize}bytes, no overlap"
			else
				echo "$blocks flash/eraseblocks@${blocksize}bytes, $overlap bytes (${percent}%) overlap into next"
			fi
		;;
		*)
			if [ -e /tmp/loader ]; then		# we are directly on a router
				. /tmp/loader
				_file size "$file"
			else
				stat --format=%s "$file"
			fi
		;;
	esac
}

uptime_in_seconds()
{
	cut -d'.' -f1 /proc/uptime
}

build_kalua_update_tarball()
{
	local option="$1"
	local mydir="$( pwd )"
	local tarball="/tmp/tarball.tgz"
	local options extract
	local file_timestamp="etc/variables_fff+"	# fixme! hackish, use pre-commit hook?

	if tar --version 2>&1 | grep -q ^BusyBox ; then
		log "detected BusyBox-tar, using simple options"
		options=
	else
		options="--owner=root --group=root"
	fi

	cd kalua/
	local last_commit_unixtime="$( git log -1 --pretty=format:%ct )"
	local last_commit_unixtime_in_hours=$(( $last_commit_unixtime / 3600 ))
	cd openwrt-addons/
	sed -i "s/366686/$last_commit_unixtime_in_hours/" "$file_timestamp"
	touch -r "../../.git/description" "$file_timestamp"

	if [ "$option" = "full" ]; then
		cp -pv ../openwrt-patches/regulatory.bin etc/init.d/apply_profile.regulatory.bin
		cp -pv ../openwrt-build/apply_profile* etc/init.d

		[ -e "../../apply_profile.code.definitions" ] && {	# custom definitions
			cp -pv "../../apply_profile.code.definitions" etc/init.d

			# insert default-definitions to custom one's
			sed -n '/^case/,/^	\*)/p' "../openwrt-build/apply_profile.code.definitions" | sed -e '1d' -e '$d' >"/tmp/defs"
			sed -i '/^case/ r /tmp/defs' "etc/init.d/apply_profile.code.definitions"
			rm "/tmp/defs"
		}

		tar $options -czf "$tarball" .
		rm etc/init.d/apply_profile*
	else
		tar $options -czf "$tarball" .
	fi

	sed -i "s/$last_commit_unixtime_in_hours/366686/" "$file_timestamp"
	touch -r "../../.git/description" "$file_timestamp"
	cd $mydir

	extract="cd /; tar xvzf $tarball; rm $tarball; /etc/kalua_init"

	echo "wrote: '$tarball' size: $( filesize "$tarball" ) bytes with MD5: $( md5sum "$tarball" | cut -d' ' -f1 )"
	echo "to copy this tarball (timestamp: $last_commit_unixtime_in_hours) to your device, use ON the device:"
	echo
	echo "scp $USER@$( mypubip ):$tarball $tarball; $extract"
	echo "or simply extract with: $extract"
	echo
	echo "or copy the config-apply-script with:"
	echo "scp $USER@$( mypubip ):$( pwd )/kalua/openwrt-build/apply_profile.code /etc/init.d"
}

config2git()
{
	local hardware destfile arch dir
	local strip="kalua/openwrt-config/hardware/strip_config.sh"
	read hardware <KALUA_HARDWARE
	

	destfile="kalua/openwrt-config/hardware/$hardware/openwrt.config"
	cp -v .config "$destfile"
	$strip "$destfile"

	architecture="$( get_arch )"
	dir=build_dir/linux-${architecture}*/linux-*
	destfile="kalua/openwrt-config/hardware/$hardware/kernel.config"
	cp -v $dir/.config "$destfile"
	$strip "$destfile"
}

get_hardware()
{
	local option="$1"
	local hardware

	read hardware <KALUA_HARDWARE

	if [ "$option" = "nickname" ]; then
		case "$hardware" in
			"Buffalo WHR-HP-G54")
				echo "buffi"
			;;
			"Linksys WRT54G:GS:GL")
				echo "linksys"
			;;
			"TP-LINK TL-WR1043ND")
				echo "tplink"
			;;
			*)
				echo "unknown"
			;;
		esac
	else
		echo "$hardware"
	fi
}

mymake()
{
	local option="$1"			# e.g. V=99
	local cpu_count="$( grep -c ^processor /proc/cpuinfo )"
	local t1 t2 date1 date2 hardware
	local filelist file

	[ -e KALUA_HARDWARE ] || echo "unknown_model" >KALUA_HARDWARE
	read hardware <KALUA_HARDWARE
	t1="$( uptime_in_seconds )"
	date1="$( date )"

	local enforce_file installation subprofile node destfile
	enforce_file="package/base-files/files/etc/init.d/apply_profile.code"
	installation="$( sed -n 's/^SIM_ARG1=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"
	subprofile="$( sed -n 's/^SIM_ARG2=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"
	node="$( sed -n 's/^SIM_ARG3=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"

	case "$( get_arch )" in
		brcm47xx)
			filelist="build_dir/linux-brcm47xx/root.squashfs \
				build_dir/linux-brcm47xx/vmlinux \
				build_dir/linux-brcm47xx/vmlinux.lzma \
				bin/brcm47xx/openwrt-brcm47xx-squashfs.trx"

			case "$hardware" in
				"Linksys WRT54G:GS:GL")
					filelist="$filelist bin/brcm47xx/openwrt-wrt54g-squashfs.bin"
				;;
			esac
		;;
		ar71xx)
			filelist="build_dir/linux-ar71xx_generic/root.squashfs \
				build_dir/linux-ar71xx_generic/vmlinux \
				build_dir/linux-ar71xx_generic/vmlinux.bin.gz"

			if [ -n "$installation" ]; then
				filelist="$filelist \
					bin/ar71xx/openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin \
					bin/ar71xx/openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-factory.bin"
			else
				filelist="$filelist \
					bin/ar71xx/openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-factory.bin \
					bin/ar71xx/openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin"
			fi
		;;
		atheros)
			filelist="build_dir/linux-atheros/vmlinux.bin.gz \
				bin/atheros/openwrt-atheros-combined.squashfs.img \
				bin/atheros/openwrt-atheros-ubnt2-pico2-squashfs.bin"
		;;
	esac

	for file in $filelist; do {
		[ -e "$file" ] && rm "$file"
	} done


	option="-j$(( $cpu_count + 1 ))${option:+ }$option"	# http://www.timocharis.com/help/jn.html
	echo "executing: 'make $option'"
	make $option || return 1


	t2="$( uptime_in_seconds )"
	date2="$( date )"
	echo "start: $date1"
	echo "ready: $date2"
	echo "'make $option' lasts $(( $t2 - $t1 )) seconds (~$(( ($t2 - $t1) / 60 )) min) for your '$hardware' (arch: $( get_arch ))"
	echo
	echo "\"Jauchzet und frohlocket...\" ob der Bytes die erschaffen wurden: (revision: $( scripts/getver.sh ))"
	echo

	for file in $filelist; do {
		if [ -e "$file" ]; then
			echo "file '$file': $( filesize "$file" ) bytes ($( filesize "$file" flashblocks ))"
		else
			calc_free_flash_space
			echo "error, file '$file' is missing, but needed"
			return 1
		fi
	} done

	calc_free_flash_space

	if [ -n "$installation" ]; then
		echo
		echo "this is an enforced profile: $installation/$subprofile/$node"
		destfile="${installation}${subprofile}${node}-$( get_hardware nickname ).bin"

		echo "copying '$file' to '/tmp/fw/$destfile'"
		mkdir -p /tmp/fw
		cp "$file" "/tmp/fw/$destfile"
	else
		destfile="."
	fi

	echo
	echo "to copy this to your device, use ON the device:"
	echo "scp $USER@$( mypubip ):$( pwd )/$file $destfile"
}

calc_free_flash_space()
{
	local flashsize flash_essential file_kernel kernel_blocks file_rootfs rootfs_blocks hardware

	read hardware <KALUA_HARDWARE
	case "$hardware" in
		"Linksys WRT54G:GS:GL"|"Buffalo WHR-HP-G54")
			blocksize="65536"
			kernel="build_dir/linux-brcm47xx/vmlinux.lzma"
			rootfs="build_dir/linux-brcm47xx/root.squashfs"
			flashsize="$(( 4 * 1024 * 1024 ))"			# 4mb
			flashsize="$(( $flashsize / $blocksize ))"
			flash_essential="$(( 4 + 1 ))"				# CFE + nvram
		;;
		"TP-LINK TL-WR1043ND")
			blocksize="65536"
			kernel="build_dir/linux-ar71xx_generic/vmlinux.bin.gz"	# always 1280kb! = 20 blocks
			kernel_blocks="$(( $(filesize "$kernel") / $blocksize ))"

			# https://dev.openwrt.org/ticket/8781
			# fixme!
			# cleanup with
			# filesize_in_blocks "$blocksize" "$file"

			[ 0 = "$(( $(filesize "$kernel") % $blocksize ))" ] || kernel_blocks="$(( $kernel_blocks + 1 ))"
			[ "$kernel_blocks" -gt 20 ] && {
				echo "your kernel is greater than possible: 1280kb/20blocks"
			}
			rootfs="build_dir/linux-ar71xx_generic/root.squashfs"
			flashsize="$(( 8 * 1024 * 1024 ))"			# 8mb
			flashsize="$(( $flashsize / $blocksize ))"
			flash_essential="2"					# uboot
		;;
	esac

	# recheck with .gz?
	# fixme! e.g. estimated: 983040 real: 760 1k-blocks

	[ -n "$kernel" ] && {
		[ -z "$kernel_blocks" ] && kernel_blocks="$(( $(filesize "$kernel") / $blocksize ))"
		[ 0 = "$(( $(filesize "$kernel") % $blocksize ))" ] || kernel_blocks="$(( $kernel_blocks + 1 ))"
		rootfs_blocks="$(( $(filesize "$rootfs") / $blocksize ))"
		[ 0 = "$(( $(filesize "$rootfs") % $blocksize ))" ] || rootfs_blocks="$(( rootfs_blocks + 1 ))"
		free_blocks="$(( $flashsize - $flash_essential - $kernel_blocks - $rootfs_blocks ))"

		echo
		echo "estimated free blocks for '$hardware' on JFFS2: $free_blocks @ $blocksize = $(( $free_blocks * $blocksize )) bytes"
	}
}

mypubip()
{
	wget -qO - http://intercity-vpn.de/scripts/getip/
}

applymystuff()
{
	local installation="$1"
	local sub_profile="$2"
	local node="$3"

	local base="package/base-files/files"
	local file destfile hash url
	local pwd="$( pwd )"

	file="kalua/openwrt-build/apply_profile"
	log "copy $( basename "$file" ) - the master controller ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d"
	chmod +x "$base/etc/init.d/$( basename "$file" )"

	file="kalua/openwrt-build/apply_profile.watch"
	log "copy $( basename "$file" ) - controller_watcher ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d"
	chmod +x "$base/etc/init.d/$( basename "$file" )"

	file="kalua/openwrt-build/apply_profile.code"
	destfile="$base/etc/init.d/apply_profile.code"
	log "copy $( basename "$file" ) - the configurator ($( filesize "$file" ) bytes)"
	cp "$file" "$destfile"

	if [ -n "$node" ]; then
		log "changing values in '$destfile'"
		sed -i "s/^#SIM_ARG1=/SIM_ARG1=$installation    #/" "$destfile"
		sed -i "s/^#SIM_ARG2=/SIM_ARG2=$sub_profile    #/" "$destfile"
		sed -i "s/^#SIM_ARG3=/SIM_ARG3=$node    #/" "$destfile"

		local startline
		startline="$( grep -n ^"# enforcing a profile" "$destfile" | cut -d':' -f1 )"
		startline="$(( $startline + 9 ))"
		head -n $startline "$destfile" | tail -n 13
	else
		log "selected generic profile"
	fi

	file="apply_profile.code.definitions"
	if [ -e "$file" ]; then
		log "copy '$file' - your network descriptions ($( filesize "$file" ) bytes)"
		cp "$file" "$base/etc/init.d"

		# extract defaults
		sed -n '/^case/,/^	\*)/p' "kalua/openwrt-build/$file" | sed -e '1d' -e '$d' >"/tmp/defs"
		# insert defaults into file
		sed -i '/^case/ r /tmp/defs' "$base/etc/init.d/$file"
		rm "/tmp/defs"

		log "copy '$file' - your network descriptions (inserted defaults also) ($( filesize "$base/etc/init.d/$file" ) bytes)"
	else
		file="kalua/openwrt-build/$file"
		log "copy '$file' - your network descriptions ($( filesize "$file" ) bytes)"
		cp "$file" "$base/etc/init.d"
	fi

	file="kalua/openwrt-patches/regulatory.bin"
	log "copy $( basename "$file" )  - easy bird grilling included ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d/apply_profile.regulatory.bin"

	[ -e "package/mac80211/files/regdb.txt" ] && {
		file="kalua/openwrt-patches/regulatory.db.txt"
		log "found package/mac80211/files/regdb.txt - overwriting"
		cp "$file" "package/mac80211/files/regdb.txt"
	}

	log "copy all_the_scripts/addons - the kalua-project itself ($( du -sh kalua/openwrt-addons ))"
	cd kalua/openwrt-addons
	cp -pR * "../../$base"

	cd "$pwd"

	file="$base/etc/HARDWARE"
	log "writing target-hardware in image '$file', to known ourselves even without klog/dmesg"
	echo "$( get_hardware | sed 's/:/\//g' )" >"$file"

	file="$base/etc/tarball_last_applied_hash"

	while [ -z "$hash" ]; do {
		url="http://intercity-vpn.de/firmware/$( get_arch )/images/testing/info.txt"
		log "fetching $url"
		hash="$( wget -qO - "$url" |
			  fgrep "tarball.tgz" |
			   cut -d' ' -f2
			)"

		[ -z "$hash" ] && {
			log "[ERR] retry in 5 sec, could not fetch '$url'"
			sleep 5
		}
	} done

	log "writing tarball-hash '$hash' into image (fooling the builtin-update-checker)"
	echo -n "$hash" >"$file"
}

set_build_openwrtconfig()
{
	local config_dir file hardware

	read hardware <KALUA_HARDWARE
	config_dir="kalua/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
	file="$config_dir/openwrt.config"
	log "applying openwrt/packages-configuration to .config ($( filesize "$file" ) bytes)"
	cp "$file" .config
	log "please launch _NOW_ 'make kernel_menuconfig' to stageup the kernel-dirs for architecture $( get_arch )"
	log "simply select exit and safe the config"
}

set_build_kernelconfig()
{
	local architecture kernel_config_dir kernel_config_file file config_dir hardware

	read hardware <KALUA_HARDWARE
	config_dir="kalua/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
	architecture="$( get_arch )"
	kernel_config_dir=build_dir/linux-${architecture}*/linux-*		# e.g. build_dir/linux-ar71xx_generic/linux-2.6.39.4
	file="$config_dir/kernel.config"
	log "applying kernel-config for arch $architecture to $kernel_config_dir/.config ($( filesize "$file" ) bytes)"
	cp "$file" $kernel_config_dir/.config

	kernel_config_file=target/linux/${architecture}*/config-*
	log "applying kernel-config for arch $architecture to $kernel_config_file ($( filesize "$file" ) bytes)"
	cp "$file" $kernel_config_file
}

select_hardware_model()		# add: "Ubiquiti PicoStation2"
{
	local specific_model="$1"
	local dir="$( dirname $0 )/../openwrt-config/hardware"
	local filename hardware i

	find "$dir/"* -type d | while read filename; do {
		hardware="$( basename "$filename" )"
		i=$(( ${i:-0} + 1 ))

		if [ -n "$specific_model" ]; then
			case "$specific_model" in
				"$i"|"$hardware")
					echo "$hardware"
				;;
			esac
		else
			echo "$i) $hardware"
		fi
	} done

	[ -z "$specific_model" ] && {
		read hardware 2>/dev/null <KALUA_HARDWARE
		echo
		echo "please select your device or hit <enter> to leave '${hardware:-empty_model}'"
		read hardware

		[ -n "$hardware" ] && {
			select_hardware_model "$hardware" >KALUA_HARDWARE
		}

		read hardware <KALUA_HARDWARE
		log "wrote model $hardware to file KALUA_HARDWARE"
	}
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

svnrev2githash()
{
	local revision="$1"

	git log --grep="svn://svn.openwrt.org/openwrt/trunk@$revision " |
	 grep ^commit |
	  cut -d' ' -f2
}

gitpull()
{
	local revision="$1"
	local hash

	[ -n "$revision" ] && {
		hash="$( svnrev2githash "$revision" )"
		echo "githash: '$hash'"
		return 0
	}

	log "updating package-feeds"
	cd ../packages
	git pull

	log "updating core-packages/build-system"
	cd ../openwrt
	git pull

	log "updated to openwrt-version: $( scripts/getver.sh )"
}

case "$ACTION" in
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
	*)
		$ACTION "$OPTION" "$OPTION2" "$OPTION3"
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
