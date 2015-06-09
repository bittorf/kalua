#!/bin/sh

ACTION="$1"
OPTION="$2"
OPTION2="$3"
OPTION3="$4"
OPTION4="$5"
OPTION5="$6"
OPTION6="$7"
OPTION7="$8"
OPTION8="$9"
OPTION9="${10}"

show_help()
{
	local me="$0"

	cat <<EOF
Usage:	$me gitpull
	$me config_diff <new_config> <old_config>
	$me set_build <list|standard|...> <...> <...>
	$me applymystuff <profile> <subprofile> <nodenumber>	# e.g. "ffweimar" "adhoc" "42"
	$me make <option>
	$me build_kalua_update_tarball [full]
	$me apport_vmlinux

Hint:   for building multiple config-enforced images use e.g.:
	APP="$0"
	for I in \$(seq 2 70); do for MODE in adhoc ap; do \$APP applymystuff "ffweimar" \$MODE \$I; \$APP make; done; done

EOF
}

if [ -z "$REPONAME" ] || [ -z "$REPOURL" ]; then
	echo "please set the variables \$REPONAME and \$REPOURL to appropriate values, e. g. \"weimarnetz\" for REPONAME and \"git://github.com/weimarnetz/weimarnetz.git\" for REPOURL"
	echo "\$REPONAME is the name of the directory where you checked out the repository \$REPOURL"
	echo ""
	show_help
	exit 1
fi

case "$ACTION" in
	"")
		show_help
		exit 1
	;;
	make)
		ACTION="mymake"
	;;
esac

[ -d $REPONAME ] || {
	echo "please make sure, that your working directory is in the openwrt-base dir"
	echo "i want to see the directorys 'package', 'scripts' and '$REPONAME'"
	exit 1
}

log()
{
	logger -s "$1"
}

kernel_dir()
{
	# build_dir/linux-brcm47xx/linux-3.3.8/
	# !!! invalid: build_dir/toolchain-mips_r2_gcc-4.6-linaro_uClibc-0.9.33.2/linux-dev/...
	# !!! invalid: build_dir/toolchain-mips_r2_gcc-4.6-linaro_uClibc-0.9.33.2/linux-3.6.10/.config
	# build_dir/target-mips_r2_uClibc-0.9.33.2/linux-ar71xx_generic/linux-3.6.10/.config

	local dir
	log "kernel_dir: pwd: '$( pwd )'"

	if [ -n "$( ls -1 build_dir/linux-* 2>/dev/null )" ]; then
		log "kernel_dir: type 1"
		dir="$( find build_dir -maxdepth 1 -type d -name 'linux-*' )"
	else
		log "kernel_dir: type 2"
		dir="$( find build_dir -maxdepth 1 -type d -name 'target-*' )"
		log "kernel_dir: now: '$dir'"
		dir="$( find $dir -maxdepth 1 -type d -name "linux-$( get_arch )*" )"
	fi

	log "kernel_dir: now: '$dir'"
	dir="$( find $dir -maxdepth 1 -type d -name 'linux-[0-9]*' )"
	log "kernel_dir: result: '$dir'"

	echo "$dir"
}

get_arch()
{
	sed -n 's/^CONFIG_TARGET_\([a-z0-9]*\)=y$/\1/p' ".config" | head -n1	# https://dev.openwrt.org/wiki/platforms
}

get_firmware_filenames()	# output is without complete path, only the files in 'bin/$arch/...'
{
	local hardware="${1:-$( cat KALUA_HARDWARE )}"
	local arch="$( get_arch )"
	local config_file="$REPONAME/openwrt-config/config_HARDWARE.${hardware}.txt"
	local found="false"
	local filetype file

	if [ -e "$config_file" ]; then
		for filetype in factory sysupgrade bootloader; do {
			grep -sq ^"# ${filetype}: " "$config_file" && {
				found="true"
				set -- $( grep ^"# ${filetype}: " "$config_file" )
				shift 2
				echo $@
			}
		} done
	else
		log "not found '$config_file' we are here: '$( pwd )'"
	fi

	[ "$found" = "false" ] && log "unknown filenames, search in 'bin/$arch/...' and read 'openwrt-config/HowTo_add_new_HARDWARE.md'"
}

apport_vmlinux()	# for better debugging of http://intercity-vpn.de/crashlog/
{
	local dir=$( echo build_dir/linux-$( get_arch )*/linux-3* )
	local dest="root@intercity-vpn.de:/var/www/crashlog"
	local revision="$( scripts/getver.sh )"

	echo "cp -v '$dir/vmlinux' /tmp; lzma -v9e '/tmp/vmlinux'"
	echo "scp '/tmp/vmlinux.lzma' '$dest/vmlinux.$( get_arch ).${revision}.lzma'; rm '/tmp/vmlinux.lzma'"
}

config_diff()
{
	local file_new="${1:-.config}"
	local file_old="${2:-.config.old}"
	local line

	[ "$file_new" = "kernel" ] && {
		file_new="$( kernel_dir )/.config"
		file_new="$( kernel_dir )/.config.old"
	}

	diff "$file_new" "$file_old" |
	 while read line; do {
		case "$line" in
			"< # CONFIG"*)
				echo "$line" | cut -b 5-
			;;
			"< CONFIG"*)
				echo "$line" | cut -b 3-
			;;
		esac
	} done
}

set_build()
{
	local mode="$1"			# e.g. mini|standard|full
	local line symbol file wish config
	local dir="$REPONAME/openwrt-config"
	local hardware

	case "$mode" in
		reset_config)
			rm ".config"
			file="/dev/null"
		;;
		unoptimized)		# https://forum.openwrt.org/viewtopic.php?id=30141
			sed -i 's/-Os //' ".config"
			sed -i 's/-Os //' "include/target.mk"

			file="/tmp/fake_$$"
			echo "CONFIG_CC_OPTIMIZE_FOR_SIZE is not set" >"$file"
			mode="kernel:cc_nooptimize"
		;;
		""|list)
			echo "possible pregenerated configs are:"
			ls -1 $dir/config_* | sed 's/^.*config_\(.*\).txt$/\1/'
			return 1
		;;
		"patch:"*)
			[ -e "$REPONAME/openwrt-patches/$( echo "$mode" | cut -d':' -f2 )" ] || {
				log "patch '$mode' does not exists"
				return 1
			}
		;;
		kcmdlinetweak)
		;;
		*)
			file="$dir/config_${mode}.txt"
			if [ -e "$file" ]; then
				case "$mode" in
					"HARDWARE."*)
						hardware="$( echo "$mode" | cut -d'.' -f2 )"
						log "writing hardware '$hardware' to 'KALUA_HARDWARE' in $(pwd)"
						echo "$hardware" >"KALUA_HARDWARE"
					;;
				esac
			else
				log "mode '$mode' not implemented yet"
				return 1
			fi
		;;
	esac

	case "$mode" in
		"patch:"*)
			file="$REPONAME/openwrt-patches/$( echo "$mode" | cut -d':' -f2 )"
			local line dest old_pwd file2patch

			read line <"$file"	# diff --git a/package/uhttpd/src/uhttpd-tls.c b/package/uhttpd/src/uhttpd-tls.c
			case "$line" in
				*"include/net/mac80211.h"|*"net/mac80211/rc80211_minstrel_ht.c"|*"net/wireless/b43/dma.c")
					dest="package/mac80211/patches"
				;;
				*"uhttpd/src/"*)
					# e.g. uhttpd-tls.c
					dest="package/network/services/uhttpd/src/"
					old_pwd="$( pwd )"
					file2patch="$( basename "$( echo "$line" | cut -d' ' -f3 )" )"
					cd $dest

					patch -N f1 f2 

					cd $old_pwd
				;;
                                *)
                                        # general, patches created with "diff -up <orig file> <patched file> > patchfile"
					# assumption: patch root dir is in openwrt directory
					# extract 2nd line from patch file
					line=$( head -n 2 $file|tail -n 1 )
                                        file2patch="$( echo "$line" | cut -d' ' -f2 |cut -f1 )"
					dest="$( dirname $file2patch )"

                                        patch -N $file2patch $file

                                ;;

			esac

			mkdir -p "$dest"
			log "we are here: '$( pwd )' - cp '$file' '$dest'"
			cp -v "$file" "$dest"

			file="/dev/null"
		;;
		meta*)
			local thismode mode_list
			read mode_list <"$file"

			for thismode in $mode_list; do {
				log "applying meta-content: $thismode"
				set_build "$thismode"
			} done
		;;
		kernel*)
			config="$( kernel_dir )/.config"
			# dir="target/linux/$( get_arch )"
			# config="$( ls -1 $dir/config-* | head -n1 )"
		;;
		kcmdlinetweak)	# https://lists.openwrt.org/pipermail/openwrt-devel/2012-August/016430.html
			dir="target/linux/$( get_arch )"
			pattern=" oops=panic panic=10"

			case "$( get_arch )" in
				ar71xx)
					config="$dir/image/Makefile"
					log "$mode: looking into '$config'"

					fgrep -q "$pattern" "$config" || {
						sed -i "s/\(KERNEL_CMDLINE=\"\)\(.*\)\(\".*\)/\1\2${pattern}\3/" "$config"
					}
				;;
				*)	# tested for brcm47xx
					config="$( ls -1 $dir/config-* | head -n1 )"
					log "$mode: looking into '$config'"

					fgrep -q "$pattern" "$config" || {
						sed -i "/^CONFIG_CMDLINE=/s/\"$/${pattern}\"/" "$config"
					}
				;;
			esac

			file="/dev/null"
		;;
		*)
			dir="$REPONAME/openwrt-config"
			config=".config"

			[ -e "$config" ] || {
				log "empty config, starting 'make defconfig' for you"
				make defconfig
			}
		;;
	esac

	[ "$file" = "/dev/null" ] || log "set_build() using '$dir/$config'"

	# fixme! respect this syntax too: (not ending on '=y' or ' is not set')
	# CONFIG_DEFCONFIG_LIST="/lib/modules/$UNAME_RELEASE/.config"

	while read line; do {
		log "apply symbol: $line"

		case "$line" in
			""|"#"*)
				# ignore comments
			;;
			*"="[0-9]*)
				symbol="$( echo "$line" | sed -n 's/\(^.*\)=.*$/\1/p' )"
				value="$( echo "$line" | sed -n 's/^.*=\(.*$\)/\1/p' )"
				wish="${symbol}=${value}"

				if grep -q ^"# $symbol is not set" "$config"; then
					# if its marked as NO, change it to the value
					sed -i "s/^# ${symbol} is not set/$wish/" "$config"
				else
					echo "$wish" >>"$config"
				fi	
			;;
			*"=\""*"\"")
				symbol="$( echo "$line" | sed -n 's/\(^.*\)=\".*\"$/\1/p' )"
				value="$( echo "$line" | sed -n 's/^.*=\(\".*\"$\)/\1/p' )"
				wish="${symbol}=${value}"

				if grep -q ^"# $symbol is not set" "$config"; then
					# if its marked as NO, change it to the value
					sed -i "s/^# ${symbol} is not set/$wish/" "$config"
				else
					echo "$wish" >>"$config"
				fi	
			;;
			*"=m")
				symbol="$( echo "$line" | sed -n 's/\(^.*\)=m/\1/p' )"
				wish="${symbol}=m"

				if grep -q ^"# $symbol is not set" "$config"; then
					# if its marked as NO, change it to m
					sed -i "s/^# ${symbol} is not set/$wish/" "$config"
				else
					echo "$wish" >>"$config"
				fi
			;;
			*"=y")
				symbol="$( echo "$line" | sed -n 's/\(^.*\)=y/\1/p' )"
				wish="${symbol}=y"

				if grep -q ^"# $symbol is not set" "$config"; then
					# if its marked as NO, change it to YES
					sed -i "s/^# ${symbol} is not set/$wish/" "$config"
				else
					echo "$wish" >>"$config"
				fi
			;;
			*" is not set")
				symbol="$( echo "$line" | sed -n 's/\(^.*\) is not set/\1/p' )"
				wish="# ${symbol} is not set"

				if grep -q ^"${symbol}=y" "$config"; then
					# if its marked as YES, change it to NO
					sed -i "s/^${symbol}=y/$wish/" "$config"
				else
					echo "$wish" >>"$config"
				fi
			;;
		esac
	} done <"$file"

	case "$file" in
		"/tmp/fake_"*)
			rm "$file"
		;;
	esac

	shift
	[ -n "$1" ] && {
		log "parsing next argument: '$1'"
		set_build "$@"
	}
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

check_scripts()
{
	local dir="$1"
	local file i mimetype

	for file in $( find $dir -type f ); do {
		case "$file" in
			"./www/images/web"*)
				mimetype="application/x-empty"
			;;
			"./etc/kalua/"*)
				mimetype="text/x-shellscript"
			;;
			*)
				mimetype="$( file --mime-type "$file" )"
			;;
		esac

		case "$mimetype" in
			*"application/xml"*)
				log "[OK] will not check xml file '$file'"
			;;
			*"text/html"*)
				log "[OK] will not check html file '$file'"
			;;
			*"text/x-c++"*)
				log "[OK] will not check c++ file '$file'"
			;;
			*"inode/x-empty"*|*"application/x-empty"*)
				log "[OK] will not check empty file '$file'"
			;;
			*"image/gif"*)
				log "[OK] will not check gfx file '$file'"
			;;
			*"application/octet-stream"*)
				log "[OK] will not check binary file '$file'"
			;;
			*"text/x-shellscript"*|*"text/plain"*)
				sh -n "$file" || {
					log "error in file '$file' - abort"
					return 1
				}
				i=$(( $i + 1 ))
			;;
			*)
				log "computer confused: type: '$mimetype' file: '$file'"
				return 1
			;;
		esac
	} done

	log "[OK] checked $i files"
	return 0
}

generate_version_file()
{
	cd $REPONAME/
	local last_commit_unixtime="$( git log -1 --pretty=format:%ct )"
	local last_commit_unixtime_in_hours=$(( $last_commit_unixtime / 3600 ))
	cd ..

	cat <<EOF
FFF_PLUS_VERSION=$last_commit_unixtime_in_hours		# $( date -d @$last_commit_unixtime )
FFF_VERSION=2.0.0		# OpenWrt based / unused
EOF
}

build_kalua_update_tarball()
{
	local option="$1"
	local mydir="$( pwd )"
	local tarball="/tmp/tarball.tgz"
	local options extract
	local file_timestamp="etc/variables_fff+"	# fixme! hackish, use pre-commit hook?
	local private_settings
	local file

	if tar --version 2>&1 | grep -q ^BusyBox ; then
		log "detected BusyBox-tar, using simple options"
		options=
	else
		options="--owner=root --group=root"
	fi

	generate_version_file >"$REPONAME/openwrt-addons/$file_timestamp"
	cd $REPONAME/
	cd openwrt-addons

	if [ "$option" = "full" ]; then
		cp -pv ../openwrt-patches/regulatory.bin etc/init.d/apply_profile.regulatory.bin
		cp -pv ../openwrt-build/apply_profile* etc/init.d

		private_settings="../../apply_profile.code.definitions"
		[ -e "$private_settings" ] || private_settings="/tmp/apply_profile.code.definitions"

		[ -e "$private_settings" ] && {
			log "using file: '$private_settings'"
			cp -pv "$private_settings" etc/init.d

			# insert default-definitions to custom one's
			sed -n '/^case/,/^	\*)/p' "../openwrt-build/apply_profile.code.definitions" | sed -e '1d' -e '$d' >"/tmp/defs_$$"
			sed -i '/^case/ r /tmp/defs' "etc/init.d/apply_profile.code.definitions"
			rm "/tmp/defs_$$"
		}

		check_scripts . || return 1
		tar $options -czf "$tarball" .
		rm etc/init.d/apply_profile*
	else
		check_scripts . || return 1
		tar $options -czf "$tarball" .
	fi

	rm "$file_timestamp"
	cd $mydir

	extract="cd /; tar xvzf $tarball; rm $tarball; /etc/kalua_init"

	echo "wrote: '$tarball' size: $( filesize "$tarball" ) bytes with MD5: $( md5sum "$tarball" | cut -d' ' -f1 )"
	echo "to copy this tarball (timestamp: $last_commit_unixtime_in_hours) to your device, use ON the device:"
	echo
	echo "scp $USER@$( mypubip ):$tarball $tarball; $extract"
	echo "or simply extract with: $extract"
	echo
	echo "or copy the config-apply-script with:"
        echo "scp $USER@$( mypubip ):$( pwd )/$REPONAME/openwrt-build/apply_profile.code /etc/init.d"	
}

config2git()
{
	local hardware destfile arch dir
	local strip="$REPONAME/openwrt-config/hardware/strip_config.sh"
	read hardware <KALUA_HARDWARE
	

	destfile="$REPONAME/openwrt-config/hardware/$hardware/openwrt.config"
	cp -v .config "$destfile"
	$strip "$destfile"

	cp -v "$( kernel_dir )/.config" "$destfile"
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

	filelist="$( get_firmware_filenames )"

	for file in $filelist; do {
		[ -e "bin/$( get_arch )/$file" ] && rm "bin/$( get_arch )/$file"
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

	echo "use these files:"
	for file in $( get_firmware_filenames ); do {
		echo "bin/$( get_arch )/$file"
	} done
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

	log "omitting calc free blocks - disabled for now"
	kernel=
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
	local file destfile hash url private_settings
	local pwd="$( pwd )"

	log "generating version-information - /etc/variables_fff+"
	generate_version_file >"$base/etc/variables_fff+"

	file="$REPONAME/openwrt-build/apply_profile"
	log "copy $( basename "$file" ) - the master controller ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d"
	chmod +x "$base/etc/init.d/$( basename "$file" )"

	file="$REPONAME/openwrt-build/apply_profile.watch"
	log "copy $( basename "$file" ) - controller_watcher ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d"
	chmod +x "$base/etc/init.d/$( basename "$file" )"

	file="$REPONAME/openwrt-build/apply_profile.code"
	destfile="$base/etc/init.d/apply_profile.code"
	log "copy $( basename "$file" ) - the configurator ($( filesize "$file" ) bytes)"
	cp "$file" "$destfile"
	chmod +x "$base/etc/init.d/$( basename "$file" )"

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

	private_settings="../../apply_profile.code.definitions"
	[ -e "$private_settings" ] || private_settings="/tmp/apply_profile.code.definitions"

	file="$private_settings"
	if [ -e "$file" ]; then
		log "copy '$file' - your network descriptions ($( filesize "$file" ) bytes)"
		cp "$file" "$base/etc/init.d"

		# extract defaults
		sed -n '/^case/,/^	\*)/p' "$REPONAME/openwrt-build/$file" | sed -e '1d' -e '$d' >"/tmp/defs_$$"
		# insert defaults into file
		sed -i '/^case/ r /tmp/defs' "$base/etc/init.d/$file"
		rm "/tmp/defs_$$"

		log "copy '$file' - your network descriptions (inserted defaults also) ($( filesize "$base/etc/init.d/$file" ) bytes)"
	else
		file="$REPONAME/openwrt-build/$( basename $file )"
		log "copy '$file' - your network descriptions ($( filesize "$file" ) bytes)"
		cp "$file" "$base/etc/init.d"
	fi

	file="$REPONAME/openwrt-patches/regulatory.bin"
	log "copy $( basename "$file" )  - easy bird grilling included ($( filesize "$file" ) bytes)"
	cp "$file" "$base/etc/init.d/apply_profile.regulatory.bin"

	[ -e "package/mac80211/files/regdb.txt" ] && {
		file="$REPONAME/openwrt-patches/regulatory.db.txt"
		log "found package/mac80211/files/regdb.txt - overwriting"
		cp "$file" "package/mac80211/files/regdb.txt"
	}

	log "copy all_the_scripts/addons - the weimarnetz-project itself ($( du -sh $REPONAME/openwrt-addons ))"
	cd $REPONAME/openwrt-addons
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
	config_dir="$REPONAME/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
	file="$config_dir/openwrt.config"
	log "applying openwrt/packages-configuration to .config ($( filesize "$file" ) bytes)"
	cp "$file" .config
	log "please launch _NOW_ 'make kernel_menuconfig' to stageup the kernel-dirs for architecture $( get_arch )"
	log "should be in: '$( kernel_dir )/.config'"
	log "simply select exit and safe the config"
}

set_build_kernelconfig()
{
	local architecture kernel_config_dir kernel_config_file file config_dir hardware

	read hardware <KALUA_HARDWARE
	config_dir="$REPONAME/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
	architecture="$( get_arch )"

	kernel_config_dir="$( kernel_dir )"
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

initial_settings()	# prepares the openwrt clone for our needs, should only run one time before compiling the first time
{
	cd $REPONAME/openwrt-build
	cp -pv vtun-Makefile ../../feeds/packages/net/vtun/Makefile
        #remove dependency manually
	#cp -pv profile-100-Broadcom-b43.mk ../../target/linux/brcm47xx/profiles/100-Broadcom-b43.mk
        cp -pv rc.local ../../package/base-files/files/etc/rc.local
	cp -pv pre-commit ../.git/hooks/pre-commit
        echo "vm.swappiness=100" >> ../../package/base-files/files/etc/sysctl.conf
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
				elif grep -q ^"CONFIG_TARGET_ar71xx_generic_TLWR703=y" .config; then
					LIST_FILES="            openwrt-ar71xx-generic-tl-wr703n-squashfs-factory.bin"
                                        LIST_FILES="$LIST_FILES openwrt-ar71xx-generic-tl-wr703n-squashfs-sysupgrade.bin"
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
		$ACTION "$OPTION" "$OPTION2" "$OPTION3" "$OPTION4" "$OPTION5" "$OPTION6" "$OPTION7" "$OPTION8" "$OPTION9"
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
