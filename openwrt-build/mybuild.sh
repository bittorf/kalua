#!/bin/sh

ACTION="$1"
OPTION="$2"
OPTION2="$3"
OPTION3="$4"

show_help()
{
	local me="$( basename $0 )"

	cat <<EOF
Usage:	$me gitpull
	$me config2git
	$me select_hardware_model
	$me set_build_openwrtconfig
	$me set_build_kernelconfig
	$me applymystuff <profile> <subprofile> <nodenumber>	# e.g. "ffweimar" "adhoc" "42"
	$me make <option>
	$me build_kalua_update_tarball
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

[ -d weimarnetz ] || {
	echo "please make sure, that your working directory is in the openwrt-base dir"
	echo "i want to see the directorys 'package', 'scripts' and 'weimarnetz'"
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
			stat --format=%s "$file"
		;;
	esac
}

uptime_in_seconds()
{
	cut -d'.' -f1 /proc/uptime
}

build_kalua_update_tarball()
{
	local mydir="$( pwd )"
	local tarball="/tmp/tarball.tgz"

	cd kalua/openwrt-addons/
	tar --owner=root --group=root -czf "$tarball" .
	cd $mydir

	echo "wrote: '$tarball' size: $( filesize "$tarball" ) bytes"
	echo "to copy this to your device, use ON the device:"
	echo
	echo "scp $USER@$( mypubip ):$tarball $tarball; cd /; tar xvzf $tarball; regen"
}

config2git()
{
	local hardware destfile arch dir
	local strip="weimarnetz/openwrt-config/hardware/strip_config.sh"
	read hardware <KALUA_HARDWARE
	

	destfile="weimarnetz/openwrt-config/hardware/$hardware/openwrt.config"
	cp -v .config "$destfile"
	$strip "$destfile"

	architecture="$( get_arch )"
	dir=build_dir/linux-${architecture}*/linux-*
	destfile="weimarnetz/openwrt-config/hardware/$hardware/kernel.config"
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

	read hardware <KALUA_HARDWARE
	t1="$( uptime_in_seconds )"
	date1="$( date )"

	case "$( get_arch )" in
		brcm47xx)
			filelist="build_dir/linux-brcm47xx/root.squashfs \
				build_dir/linux-brcm47xx/vmlinux \
				build_dir/linux-brcm47xx/vmlinux.lzma \
				bin/brcm47xx/openwrt-brcm47xx-squashfs.trx \
				bin/brcm47xx/openwrt-wrt54g-squashfs.bin"
		;;
		ar71xx)
			filelist="build_dir/linux-ar71xx_generic/root.squashfs \
				build_dir/linux-ar71xx_generic/vmlinux \
				build_dir/linux-ar71xx_generic/vmlinux.bin.gz \
				bin/ar71xx/openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-factory.bin \
				bin/ar71xx/openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin"
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
	echo '"Jauchzet und frohlocket..." ob der Bytes die erschaffen wurden:'
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

	local enforce_file installation subprofile node destfile
	enforce_file="package/base-files/files/etc/init.d/apply_profile.code"
	installation="$( sed -n 's/^SIM_ARG1=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"
	subprofile="$( sed -n 's/^SIM_ARG2=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"
	node="$( sed -n 's/^SIM_ARG3=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"

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
		"Linksys WRT54G:GS:GL")
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
	local file destfile hash
	local pwd="$( pwd )"

	file="weimarnetz/openwrt-build/apply_profile"
	log "copy $( basename "$file" ) - the master controller ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d"

	file="weimarnetz/openwrt-build/apply_profile.code"
	destfile="$base/etc/init.d/apply_profile.code"
	log "copy $( basename "$file" ) - the configurator ($( filesize "$file" ) bytes)"
	cp "$file" "$destfile"

	if [ -n "$node" ]; then
		echo "changing values in '$destfile'"
		sed -i "s/^#SIM_ARG1=/SIM_ARG1=$installation    #/" "$destfile"
		sed -i "s/^#SIM_ARG2=/SIM_ARG2=$sub_profile    #/" "$destfile"
		sed -i "s/^#SIM_ARG3=/SIM_ARG3=$node    #/" "$destfile"

		local startline
		startline="$( grep -n ^"# enforcing a profile" "$destfile" | cut -d':' -f1 )"
		startline="$(( $startline + 9 ))"
		head -n $startline "$destfile" | tail -n 13
	else
		echo "selected generic profile"
	fi

	file="weimarnetz/openwrt-build/apply_profile.code.definitions"
	log "copy $( basename "$file" )  - your network descriptions ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d"

	file="weimarnetz/openwrt-patches/regulatory.bin"
	log "copy $( basename "$file" )  - easy bird grilling included ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d/apply_profile.regulatory.bin"

	log "copy all_the_scripts/addons - the weimarnetz-project itself ($( du -sh weimarnetz/openwrt-addons ))"
	cd weimarnetz/openwrt-addons
	cp -R * "../../$base"

	cd "$pwd"

	file="$base/etc/HARDWARE"
	log "writing target-hardware in image '$file', to known ourselves even without klog/dmesg"
	echo "$( get_hardware | sed 's/:/\//g' )" >"$file"

	file="$base/etc/tarball_last_applied_hash"
	hash="$( wget -qO - "http://intercity-vpn.de/firmware/$( get_arch )/images/testing/info.txt" | fgrep "tarball.tgz" | cut -d' ' -f2 )"
	log "writing tarball-hash '$hash' into image (fooling the builtin-update-checker)"
	echo -n "$hash" >"$file"
}

set_build_openwrtconfig()
{
	local config_dir file hardware

	read hardware <KALUA_HARDWARE
	config_dir="weimarnetz/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
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
	config_dir="weimarnetz/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
	architecture="$( get_arch )"
	kernel_config_dir=build_dir/linux-${architecture}*/linux-*		# e.g. build_dir/linux-ar71xx_generic/linux-2.6.39.4
	file="$config_dir/kernel.config"
	log "applying kernel-config for arch $architecture to $kernel_config_dir/.config ($( filesize "$file" ) bytes)"
	cp "$file" $kernel_config_dir/.config

	kernel_config_file=target/linux/${architecture}*/config-*
	log "applying kernel-config for arch $architecture to $kernel_config_file ($( filesize "$file" ) bytes)"
	cp "$file" $kernel_config_file
}

select_hardware_model()
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
