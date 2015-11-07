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

case "$ACTION" in
	"")
		show_help
		exit 1
	;;
	make)
		ACTION="mymake"
	;;
esac

# use e.g. 'ln -s source kalua' on devstation
[ -d 'kalua' ] || {
	echo "please make sure, that your working directory is in the openwrt-base dir"
	echo "i want to see the directorys 'package', 'scripts' and 'kalua'"
#	exit 1
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
	local config_file="kalua/openwrt-config/config_HARDWARE.${hardware}.txt"
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
	 while read -r line; do {
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
	local dir="kalua/openwrt-config"
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
			[ -e "kalua/openwrt-patches/$( echo "$mode" | cut -d':' -f2 )" ] || {
				log "patch '$mode' does not exists"
				return 1
			}
		;;
		kcmdlinetweak)
		;;
		*)
			if [ -e "$mode" ]; then
				file="$mode"
			else
				file="$dir/config_${mode}.txt"
			fi

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
			file="kalua/openwrt-patches/$( echo "$mode" | cut -d':' -f2 )"
			local line dest old_pwd file2patch

			read -r line <"$file"	# diff --git a/package/uhttpd/src/uhttpd-tls.c b/package/uhttpd/src/uhttpd-tls.c
			case "$line" in
				*"include/net/mac80211.h"|*"net/mac80211/rc80211_minstrel_ht.c"|*"net/wireless/"*)
					dest="package/kernel/mac80211/patches"
				;;
				*"uhttpd/src/"*)
					# e.g. uhttpd-tls.c
					dest="package/network/services/uhttpd/src/"
					old_pwd="$( pwd )"
					file2patch="$( basename "$( echo "$line" | cut -d' ' -f3 )" )"
					cd $dest

					patch f1 f2

					cd $old_pwd
				;;
                                *)
                                        # general, patches created with "diff -up <orig file> <patched file> > patchfile"
					# assumption: patch root dir is in openwrt directory
					# extract 2nd line from patch file
					line=$( head -n 2 $file|tail -n 1 )
                                        file2patch="$( echo "$line" | cut -d' ' -f2 |cut -f1 )"
					dest="$( dirname $file2patch )"

                                        patch  $file2patch $file

                                ;;

			esac

			mkdir -p "$dest"
			log "we are here: '$( pwd )' - cp '$file' '$dest'"
			cp -v "$file" "$dest"

			file="/dev/null"
		;;
		meta*)
			local thismode mode_list
			read -r mode_list <"$file"

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
			pattern=" oops=panic panic=10 "

			case "$( get_arch )" in
				ar71xx)
					config="$dir/image/Makefile"
					log "$mode: looking into '$config'"

					fgrep -q "$pattern" "$config" || {
						sed -i "s/console=/$pattern &/" "$config"
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
			dir="kalua/openwrt-config"
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

	while read -r line; do {
		case "$line" in
			'CONFIG_PACKAGE_ATH_DEBUG=y')
				grep -q 'CONFIG_PACKAGE_kmod-ath=y' "$config" || {
					log "no 'kmod-ath' involved - ignoring '$line'"
					line=
				}
			;;
		esac

		case "$line" in
			""|"#"*)
				# ignore comments
			;;
			*"=y")
				log "apply symbol: $line"

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
				log "apply symbol: $line"

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
			read -r hardware <KALUA_HARDWARE

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
	cd kalua/
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

	generate_version_file >"kalua/openwrt-addons/$file_timestamp"
	cd kalua/
	cd openwrt-addons

	if [ "$option" = "full" ]; then
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
	echo "to copy this tarball (timestamp: $last_commit_unixtime_in_hours) to your device, use _on_ the device:"
	echo
	echo "scp $USER@$( mypubip ):$tarball $tarball; $extract"
	echo "OR"
	echo "scp $USER@$( mypubip ):$tarball $tarball && _firmware update_pmu $tarball"
	echo "OR"
	echo "or simply extract with: $extract"
	echo
	echo "or copy the config-apply-script with:"
	echo "scp $USER@$( mypubip ):$( pwd )/kalua/openwrt-build/apply_profile.code /etc/init.d"
}

config2git()
{
	local hardware destfile arch dir
	local strip="kalua/openwrt-config/hardware/strip_config.sh"
	read -r hardware <KALUA_HARDWARE

	destfile="kalua/openwrt-config/hardware/$hardware/openwrt.config"
	cp -v .config "$destfile"
	$strip "$destfile"

	cp -v "$( kernel_dir )/.config" "$destfile"
	$strip "$destfile"
}

get_hardware()
{
	local option="$1"
	local hardware

	read -r hardware <KALUA_HARDWARE

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
	read -r hardware <KALUA_HARDWARE
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

	read -r hardware <KALUA_HARDWARE
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
	local default_route="$( ip route list exact '0.0.0.0/0' )"
	local ip

	if [ -n "$default_route" ]; then
		wget -qO - 'http://intercity-vpn.de/scripts/getip/' || {
			set -- $default_route
			while shift; do {
				case "$1" in
					*'.'*)
						ip="$1"
						break
					;;
					'')
						break
					;;
				esac
			} done

			# 192.168.0.1 dev wlan0  src 192.168.0.61 \    cache
			set -- $( ip -oneline route get "$ip" )

			while shift; do {
				case "$1" in
					'src')
						echo "$2"
						break
					;;
					'')
						break
					;;
				esac
			} done
		}
	else
		:
		# first ip of wifi or lan?
	fi
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

	file="package/base-files/files/lib/preinit/99_10_failsafe_login"
	grep -q "sleep" "$file" || {
		log "patching failsafe for autoreboot after 1h"
		sed -i 's|\&1|\&1; ( sleep 3600; sync; /sbin/reboot -f ) \&|' "$file"
	}

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

	file="kalua/openwrt-addons/etc/init.d/zram"
	destfile="package/system/zram-swap/files/zram.init"
	log "copy $( basename "$file" ) - zram-init ($( filesize "$file" ) bytes)"
	cp -v "$file" "$destfile"

	private_settings="../../apply_profile.code.definitions"
	[ -e "$private_settings" ] || private_settings="/tmp/apply_profile.code.definitions"

	file="$private_settings"
	if [ -e "$file" ]; then
		local file_in_image="$base/etc/init.d/$( basename "$file" )"
		local repo_defaults="kalua/openwrt-build/apply_profile.code.definitions"

		log "copy '$file' - your network descriptions ($( filesize "$file" ) bytes)"
		cp "$file" "$base/etc/init.d"

		# 1) head of private_settings including first 'case'
		# 2) extract defaults, all case-statements/networks without decoration
		# 3) extract private settings, all case-statements/networks without decoration
		# 4) append tail of private_settings

		sed -n '/#!\/bin\/sh/,/^case .*/p' "$private_settings"		 	 >"$file_in_image"
		sed -n '/^case/,/^	\*)/p' "$repo_defaults" | sed -e '1d' -e '$d'	>>"$file_in_image"
		sed -n '/^case/,/^	\*)/p' "$file" 	 | sed -e '1d' -e '$d'		>>"$file_in_image"
		sed -n '/^	\*)/,/^esac/p' "$private_settings"			>>"$file_in_image"

		if sh -n "$file_in_image"; then
			log "copy '$file' - your network descriptions (inserted defaults also) ($( filesize "$file_in_image" ) bytes)"
		else
			log "[ERR] mixed up syntax in '$file_in_image'"
			exit 1
		fi
	else
		file="kalua/openwrt-build/$file"
		log "copy '$file' - your network descriptions ($( filesize "$file" ) bytes)"
		cp "$file" "$base/etc/init.d"
	fi

	file="kalua/package/mac80211/patches/900-regulatory-test.patch"
	[ -e "$file" ] && {
		if grep -q "CONFIG_PACKAGE_kmod-ath9k=y" ".config"; then
			COMPAT_WIRELESS="2013-06-27"
			log "patching ath9k/compat-wireless $COMPAT_WIRELESS for using all channels ('birdkiller-mode')"
			cp -v "$file" "package/kernel/mac80211/patches"
			sed -i "s/YYYY-MM-DD/${COMPAT_WIRELESS}/g" "package/kernel/mac80211/patches/$( basename "$file" )"
			log "using another regdb"
			cp "package/kernel/mac80211/files/regdb.txt" "package/kernel/mac80211/files/regdb.txt_original"
			cp -v "kalua/openwrt-patches/regulatory.db.txt" "package/kernel/mac80211/files/regdb.txt"
		else
			[ -e "package/kernel/mac80211/files/regdb.txt_old" ] && {
				cp -v "package/kernel/mac80211/files/regdb.txt_original" "package/kernel/mac80211/files/regdb.txt"
			}
		fi
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

	read -r hardware <KALUA_HARDWARE
	config_dir="kalua/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
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

	read -r hardware <KALUA_HARDWARE
	config_dir="kalua/openwrt-config/hardware/$( select_hardware_model "$hardware" )"
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

	find "$dir/"* -type d | while read -r filename; do {
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
		read -r hardware 2>/dev/null <KALUA_HARDWARE
		echo
		echo "please select your device or hit <enter> to leave '${hardware:-empty_model}'"
		read -r hardware

		[ -n "$hardware" ] && {
			select_hardware_model "$hardware" >KALUA_HARDWARE
		}

		read -r hardware <KALUA_HARDWARE
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
					log "trying to apply ath9k/register-reading patch"
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

	log "updating feeds"
	cd ../openwrt
	scripts/feeds update

	log "updating core-packages/build-system"
	git pull

	log "updated to openwrt-version: $( scripts/getver.sh )"
}

copy_images_to_server()
{
	local option="$1"		# e.g. factory|sysupgrade|release|remove
	local size_small_image=3670020	# 56 blocks, so jffs2 is working
	local image_bigbrother_pattern='CONFIG_PACKAGE_ffmpeg=y'
	local image_audioplay_pattern='CONFIG_PACKAGE_madplay=y'
	local image_specialname
	local testfile bytes

	[ "$option" = "remove" ] && {
		log "removing: 'bin/$ARCH'"
		rm -fR bin/$ARCH
		exit 0
	}

	cd kalua
	KALUA_REF="$( git log --pretty=oneline --abbrev-commit | head -n1 | cut -d' ' -f1 )"
	KALUA_REF="git.${KALUA_REF}"								# e.g. git479d47b
	cd ..

	local enforce_file installation subprofile node destfile imagetype description
	enforce_file="package/base-files/files/etc/init.d/apply_profile.code"
	installation="$( sed -n 's/^SIM_ARG1=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"
	subprofile="$( sed -n 's/^SIM_ARG2=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"
	node="$( sed -n 's/^SIM_ARG3=\(.*\)#.*/\1/p' "$enforce_file" | cut -d' ' -f1 )"

	if [ -n "$installation" -o "$option" = "factory" ]; then
		# -profile.liszt28_hybrid94
		description="-profile.${installation}_${subprofile}${node}"
		[ -z "$installation" ] && description=
		imagetype="factory"
	else
		description=
		imagetype="sysupgrade"
	fi

	grep -q ^"$image_bigbrother_pattern"$ '.config' && image_specialname='bigbrother'
	grep -q ^"$image_audioplay_pattern"$  '.config' && image_specialname='audioplay'
	[ -n "$image_specialname" ] && {
		log "detected '$image_specialname'-image"
		image_specialname="option=${image_specialname}."
	}

	ARCH="$( get_arch )"
	KERNEL="$( grep ^"LINUX_VERSION:=" target/linux/$ARCH/Makefile | cut -d'=' -f2 )"	# e.g. 3.8.13
	REV="$( scripts/getver.sh )"								# e.g. r37012

	if [ "$option" = "release" ]; then
		APPEND="${image_specialname}${imagetype}.bin"
	else
		# r38537-kernel3.10.17-git.17ca90a.sysupgrade.bin
		APPEND="${REV}-kernel${KERNEL}-${KALUA_REF}${description}.${image_specialname}${imagetype}.bin"
	fi

	APPEND="$APPEND'"		# mind the '

	SERVER="root@intercity-vpn.de"
	SERVER_PATH="/var/www/firmware/$ARCH/images/testing"
	PRE="$SERVER:'$SERVER_PATH"	# mind the '

	work()
	{
		local file_local="$1"
		local destination="$2"
		local i=0 max=25

		if [ -e "$file_local" ]; then
			log "$file_local -> $destination"
		else
			log "file not found: '$file_local'"
			return 1
		fi

		while true; do {
			if scp "$file_local" "$destination"; then
				return 0
			else
				i=$(( i + 1 ))

				if [ $i -gt $max ]; then
					log "[ERR] scp abort"
					return 1
				else
					log "[scp_retry] $i/$max"
					sleep 5
				fi
			fi
		} done
	}

	fileX_to_modelY()
	{
		local build_filename="$1"
		local resulting_filename="$2"
		local pre
		local post="-squashfs-${imagetype}.bin"		# 'sysupgrade' or 'factory'

		case "$ARCH" in
			au1000)
				pre="openwrt-au1000-"
				post="-sysupgrade.bin"
			;;
			atheros)
				pre="openwrt-"
				post=".squashfs.img"
			;;
			brcm63xx)
				pre="openwrt-"
				post="-squashfs-cfe.bin"
			;;
			brcm47xx)
				pre="openwrt-"
				post="-squashfs.trx"
			;;
			ar71xx)
				pre="openwrt-ar71xx-generic-"
			;;
			mpc85xx)
				pre="openwrt-mpc85xx-generic-"
			;;
		esac

		work bin/$ARCH/${pre}${build_filename}${post} "$PRE/${resulting_filename}.$APPEND"
	}

	case "$ARCH" in
		au1000)
			fileX_to_modelY "au1500" "T-Mobile InternetBox.sysupgrade.bin"
			fileX_to_modelY "au1500" "4G MeshCube.sysupgrade.bin"
			fileX_to_modelY 'au1500' '4G Systems MTX-1 Board'
		;;
		atheros)
			fileX_to_modelY "atheros-combined" "Ubiquiti Nanostation2.sysupgrade.bin"
			fileX_to_modelY "atheros-combined" "Ubiquiti Nanostation5.sysupgrade.bin"
			fileX_to_modelY "atheros-combined" "Ubiquiti Picostation2.sysupgrade.bin"
			fileX_to_modelY "atheros-combined" "Ubiquiti Picostation5.sysupgrade.bin"
			fileX_to_modelY "atheros-combined" "Ubiquiti PicoStation5.sysupgrade.bin"
			fileX_to_modelY "atheros-combined" "Ubiquiti Litestation5.sysupgrade.bin"
		;;
		brcm63xx)
			fileX_to_modelY "SPW500V" "Targa WR-500-VoIP"
			fileX_to_modelY "SPW500V" "Speedport W500V"
		;;
		brcm47xx)
			fileX_to_modelY "brcm47xx" "Linksys WRT54G:GS:GL"
			fileX_to_modelY "brcm47xx" "Buffalo WHR-HP-G54"
			fileX_to_modelY "brcm47xx" "Dell TrueMobile 2300"
			fileX_to_modelY "brcm47xx" "ASUS WL-500g Premium"
		;;
		ar71xx)
			testfile="bin/$ARCH/openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-sysupgrade.bin"
			bytes="$( stat --format=%s "$testfile" 2>/dev/null )"

			if [ ${bytes:-9999999} -le $size_small_image ]; then
				fileX_to_modelY "tl-wr703n-v1"   "TP-LINK TL-WR703N v1"
				fileX_to_modelY "tl-wr841nd-v7"  "TP-LINK TL-WR841N:ND v7"
				fileX_to_modelY "tl-wr841n-v8"   "TP-LINK TL-WR841N:ND v8"
			else
				fileX_to_modelY "tl-wr1043nd-v1" "TP-LINK TL-WR1043ND"
				fileX_to_modelY "tl-wdr4300-v1"  "TP-LINK TL-WDR3600:4300:4310"
				fileX_to_modelY "wzr-hp-ag300h"  "Buffalo WZR-HP-AG300H"
				fileX_to_modelY "ubnt-bullet-m"	 "Ubiquiti Bullet M"
				fileX_to_modelY "ubnt-bullet-m"	 "Ubiquiti Picostation M2"	# same file for other router
				fileX_to_modelY "ubnt-nano-m"	 "Ubiquiti Nanostation M"
			fi
		;;
		mpc85xx)
			fileX_to_modelY "tl-wdr4900-v1"	"TP-LINK TL-WDR4900 v1"
		;;
		*)
			log "arch $ARCH in implemented yet"
		;;
	esac
}

case "$ACTION" in
	upload)
		for ARG in "$OPTION" "$OPTION2" "$OPTION3" "$OPTION4" "$OPTION5" "$OPTION6" "$OPTION7" "$OPTION8" "$OPTION9"; do {
			copy_images_to_server "$ARG"
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
