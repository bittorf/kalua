#!/bin/sh

# ToDo:
# - support for tarball
# - support for reverting specific openwrt-commits (for building older kernels)
# - apply kernel_symbols
#   - NO: ??? /home/bastian/j/openwrt/build_dir/target-mips_34kc_uClibc-0.9.33.2/linux-ar71xx_generic/linux-3.10.17/.config
#   - back to normal state: git checkout -- /home/bastian/j/openwrt/target/linux/ar71xx/config-3.10
# - options: noWiFi, noSSH (+login-patch), noOPKG, noIPTables, Failsafe
# - packages/feeds/openwrt: checkout specific version
#   - http://stackoverflow.com/questions/6990484/git-checkout-by-date
#   - hash="$( git rev-list -n 1 --before="2009-07-27 13:37" master )"
# - build release-dir
# - hardware: all models
# - build jffs2-images too
# - kalua: copy patches
# - build for whole arch (no subtarget)?
# - build with 'weimarnetz'
# - autodeps for kalua-functions and strip unneeded ones, when e.g. db() is not needed?
# - build for each router in monitoring? "build for network olympia"
# - attic not in bin/$ARCH/attic but ../attic? -> make dirclean will remove it
# - option: failsafe-image: add 'failsafe=' to kernel-commandline
# - include/renew patches for awk-remove

log()
{
	local message="$1"
	local debug="$2"

	[ -n "$QUIET" ] && return 0
	[ -n "$debug" -a -z "$DEBUG" ] && return 0
	logger -p user.info -s "$0: $message"
}

print_usage_and_exit()
{
	local hint="$1"

	[ -n "$hint" ] && log "[HINT:] $hint"

	cat <<EOF

Use: $0	--openwrt r38675|trunk|<empty> = leave untouched
	--hardware 'Ubiquiti Bullet M'|<empty> = list supported models
	--kernel
	--usecase
	--profile 'ffweimar.hybrid.120'
	--release 'stable' 'user@server:/your/path'	# copy sysupgrade-file without all details = 'Ubiquiti Bullet M.sysupgrade.bin'
	--debug
	--force
	--quiet

e.g. $0	--openwrt trunk --hardware 'Ubiquiti Bullet M' --usecase $KALUA_DIRNAME,Standard,VDS

EOF

	exit 1
}

kernel_commandline_tweak()	# https://lists.openwrt.org/pipermail/openwrt-devel/2012-August/016430.html
{
	local funcname='kernel_commandline_tweak'
	local dir="target/linux/$ARCH"
	local pattern=" oops=panic panic=10 "
	local config

	case "$ARCH" in
		ar71xx)
			config="$dir/image/Makefile"
			log "$funcname() looking into '$config', adding $pattern"

			fgrep -q "$pattern" "$config" || {
				sed -i "s/console=/$pattern &/" "$config"
			}
		;;
		*)	# tested for brcm47xx
			config="$( ls -1 $dir/config-* | head -n1 )"
			log "$funcname: looking into '$config', adding $pattern"

			fgrep -q "$pattern" "$config" || {
				sed -i "/^CONFIG_CMDLINE=/s/\"$/${pattern}\"/" "$config"
			}
		;;
	esac
}

apply_wifi_reghack()
{
	local funcname='apply_wifi_reghack'
	local file="kalua/package/mac80211/patches/900-regulatory-test.patch"
	local COMPAT_WIRELESS="2013-06-27"

	[ -e "$file" ] && {
		if grep -q "CONFIG_PACKAGE_kmod-ath9k=y" ".config"; then
			log "$funcname() patching ath9k/compat-wireless $COMPAT_WIRELESS for using all channels ('birdkiller-mode')"

			cp -v "$file" "package/kernel/mac80211/patches"
			sed -i "s/YYYY-MM-DD/${COMPAT_WIRELESS}/g" "package/kernel/mac80211/patches/$( basename "$file" )"

			log "$funcname() using another regdb"
			cp "package/kernel/mac80211/files/regdb.txt" "package/kernel/mac80211/files/regdb.txt_original"
			cp -v "kalua/openwrt-patches/regulatory.db.txt" "package/kernel/mac80211/files/regdb.txt"
		else
			[ -e "package/kernel/mac80211/files/regdb.txt_old" ] && {
				cp -v "package/kernel/mac80211/files/regdb.txt_original" "package/kernel/mac80211/files/regdb.txt"
			}
		fi
	}
}

copy_additional_packages()
{
	local funcname='copy_additional_packages'
	local dir install_section file package

	for dir in $KALUA_DIRNAME/openwrt-packages/* ; do {
		if [ -e "$dir/Makefile" ]; then
			install_section="$( fgrep 'SECTION:=' "$dir/Makefile" | cut -d'=' -f2 )"
			package="$( basename "$dir" )"

			log "$funcname() working on '$dir', destination: '$install_section'"
			cp -Rv "$dir" "package/$install_section"

			[ "$package" = 'cgminer' ] && {
				case "$LIST_USER_OPTIONS" in
					*'BTCminerCPU'*)
						file="package/$install_section/$package/Makefile"
						sed -i 's/PKG_REV:=.*/PKG_REV:=1a8bfad0a0be6ccbb2cc88917d233ac5db08a02b/' "$file"
						sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2.11.3/' "$file"
						sed -i 's/--enable-bflsc/--enable-cpumining/' "$file"
					;;
				esac
			}
		else
			log "$funcname() no Makefile found in '$dir' - please check"
			return 1
		fi
	} done

	return 0
}

target_hardware_set()
{
	local funcname='target_hardware_set'
	local model="$1"
	local option="$2"
	local line
	local version="$( echo "$model" | sed -n 's/^.* v\([0-9]\)$/\1/p' )"	# must match ' v[0-9]'

	case "$model" in
		'PC Engines ALIX.2')
			# http://wiki.openwrt.org/toh/pcengines/alix
			TARGET_SYMBOL='CONFIG_TARGET_x86_alix2=y'
			FILENAME_SYSUPGRADE='openwrt-x86-alix2-combined-squashfs.img'
			FILENAME_FACTORY="$FILENAME_SYSUPGRADE"
		;;
		'Buffalo WZR-HP-AG300H')
			# http://wiki.openwrt.org/toh/buffalo/wzr-hp-ag300h
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_WZRHPAG300H=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-wzr-hp-ag300h-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-wzr-hp-ag300h-squashfs-factory.bin'
			# openwrt-ar71xx-generic-wzr-hp-ag300h-squashfs-tftp.bin
		;;
		'TP-LINK TL-WR703N v1')
			# http://wiki.openwrt.org/toh/tp-link/tl-wr703n
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR703=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-factory.bin'

#			MAX_SIZE='3.735.556'	# 57 erase-blocks * 64k + 4 bytes padding = 3.735.552 -> klog: jffs2: Too few erase blocks (4)
#			confirmed: 3.604.484 = ok
			MAX_SIZE=$(( 56 * 65536 ))
		;;
		'TP-LINK TL-MR3020')
			# http://wiki.openwrt.org/toh/tp-link/tl-mr3020
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLMR3020=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-mr3020-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-mr3020-v1-squashfs-factory.bin'
		;;
		'TP-LINK TL-WR741ND v1'|'TP-LINK TL-WR741ND v2'|'TP-LINK TL-WR741ND v4')
			# http://wiki.openwrt.org/toh/tp-link/tl-wr741nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR741=y'
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-tl-wr741nd-v${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-tl-wr741nd-v${version}-squashfs-factory.bin"
		;;
		'TP-LINK TL-WR841N/ND v7')
			# http://wiki.openwrt.org/de/toh/tp-link/tl-wr841nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR841=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr841nd-v7-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr841nd-v7-squashfs-factory.bin'
		;;
		'TP-LINK TL-WR841N/ND v8')
			# http://wiki.openwrt.org/de/toh/tp-link/tl-wr841nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR841=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr841n-v8-squashfs-factory.bin'
		;;
		'TP-LINK TL-WDR4300')
			# http://wiki.openwrt.org/toh/tp-link/tl-wdr4300
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWDR4300=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wdr4300-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wdr4300-v1-squashfs-factory.bin'
		;;
		'TP-LINK TL-WDR4900 v1')
			# http://wiki.openwrt.org/toh/tp-link/tl-wdr4900
			TARGET_SYMBOL='CONFIG_TARGET_mpc85xx_TLWDR4900=y'
			FILENAME_SYSUPGRADE='openwrt-mpc85xx-generic-tl-wdr4900-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-mpc85xx-generic-tl-wdr4900-v1-squashfs-factory.bin'
		;;
		'TP-LINK TL-WR940N'|'TP-LINK TL-WR941ND v4')
			# http://wiki.openwrt.org/toh/tp-link/tl-wr940n
			# http://wiki.openwrt.org/toh/tp-link/tl-wr941nd
			# todo: can be v2, v3, v4, v6
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR941=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr941nd-v4-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr941nd-v4-squashfs-factory.bin'
		;;
		'TP-LINK TL-WR1043ND')
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR1043=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation5')
			TARGET_SYMBOL='CONFIG_TARGET_atheros_Default=y'
			FILENAME_SYSUPGRADE='openwrt-atheros-combined.squashfs.img'
			FILENAME_FACTORY='openwrt-atheros-ubnt5-squashfs.bin'
		;;
		'Ubiquiti Bullet M')
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_UBNT=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation M')
			TARGET_SYMBOL="CONFIG_TARGET_ar71xx_generic_UBNT=y"
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-nano-m-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-nano-m-squashfs-factory.bin'
		;;
		'Targa WR-500-VoIP'|'Speedport W500V')
			TARGET_SYMBOL='CONFIG_TARGET_brcm63xx_generic=y'
			FILENAME_SYSUPGRADE='openwrt-SPW500V-squashfs-cfe.bin'
			FILENAME_FACTORY=
		;;
		'Linksys WRT54G/GS/GL')
			TARGET_SYMBOL='CONFIG_TARGET_brcm47xx_Broadcom-b44-b43=y'
			FILENAME_SYSUPGRADE='openwrt-brcm47xx-squashfs.trx'
			FILENAME_FACTORY='openwrt-wrt54g-squashfs.bin'
		;;
		'Buffalo WHR-HP-G54'|'Dell TrueMobile 2300'|'ASUS WL-500g Premium')
			TARGET_SYMBOL='CONFIG_TARGET_brcm47xx_Broadcom-b44-b43=y'
			FILENAME_SYSUPGRADE='openwrt-brcm47xx-squashfs.trx'
			FILENAME_FACTORY=
		;;
		'T-Mobile InternetBox'|'4G Systems MTX-1 Board')
			TARGET_SYMBOL='CONFIG_TARGET_au1000_au1500=y'
			FILENAME_SYSUPGRADE='openwrt-au1000-au1500-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-au1000-au1500-vmlinux-flash.srec'
			# 'openwrt-au1000-au1500-squashfs.srec'
		;;
		'D-Link DIR-300-B1')
			# http://wiki.openwrt.org/toh/d-link/dir-300revb
			TARGET_SYMBOL='CONFIG_TARGET_ramips_rt305x_Default=y'
			FILENAME_SYSUPGRADE='openwrt-ramips-rt305x-dir-300-b1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ramips-rt305x-dir-300-b1-squashfs-factory.bin'
		;;
		'list')
			[ "$option" = 'plain' ] || log "$funcname() supported models:"

			parse_case_patterns "$funcname" | while read line; do {
				if [ "$option" = 'plain' ]; then
					echo "$line"
				else
					echo "--hardware '$line'"
				fi
			} done

			return 0
		;;
		*)
			log "model '$model' not supported"

			return 1
		;;
	esac

	# e.g. 'CONFIG_TARGET_brcm47xx_Broadcom-b44-b43=y' -> 'brcm47xx'
	ARCH="$( echo "$TARGET_SYMBOL" | cut -d'_' -f3 )"

	# 'Linksys WRT54G/GS/GL' -> 'Linksys WRT54G:GS:GL'
	HARDWARE_MODEL_FILENAME="$( echo "$HARDWARE_MODEL" | sed 's|/|:|g' )"

	VERSION_KERNEL="$( grep ^'LINUX_VERSION:=' "target/linux/$ARCH/Makefile" | cut -d'=' -f2 )"
	[ -n "$VERSION_KERNEL_FORCE" ] && {
		log "$funcname() enforce kernel version '$VERSION_KERNEL_FORCE', was '$VERSION_KERNEL'"
		VERSION_KERNEL="$VERSION_KERNEL_FORCE"
		sed -i "s/^LINUX_VERSION:=.*/LINUX_VERSION:=${VERSION_KERNEL_FORCE}/" "target/linux/$ARCH/Makefile"
	}

	log "$funcname() architecture: '$ARCH' model: '$model' kernel: '$VERSION_KERNEL'"

	apply_symbol 'nuke_config'
	apply_symbol "CONFIG_TARGET_${ARCH}=y"
	apply_symbol "$TARGET_SYMBOL"
	build defconfig
}

check_working_directory()
{
	local funcname='check_working_directory'
	local pattern='git-svn-id'
	local error=1
	local i=0

	[ -n "$FORCE" ] && error=0

	[ -d 'package/feeds' ] || {
		log "$funcname() missing 'package/symlinks', getting feeds"
		make package/symlinks
	}

	git log -1 | grep -q "$pattern" || {
		if git log | grep -q "$pattern"; then
			log "$funcname() the last commit MUST include '$pattern', seems you have private"
			log "$funcname() commits - please rollback several times via: git reset --soft HEAD^"

			while ! git log -$i | grep -q "$pattern"; do {
				i=$(( $i + 1 ))
			} done

			log "$funcname() or just do: git reset --soft HEAD~$i"
			log "$funcname() you can switch back via: git reflog; git reset \$hash"
		else
			log "$funcname() please make sure, that you are in OpenWrt's git-root"
		fi

		return $error
	}

	ls -d "$KALUA_DIRNAME" >/dev/null || {
		log "$funcname() please make sure, that directory '$KALUA_DIRNAME' exists"
		return $error
	}
}

openwrt_download()
{
	local funcname='openwrt_download'
	local wish="${1:-leave_untouched}"
	local hash branch

	log "$funcname() apply '$wish'"

	case "$wish" in
		'leave_untouched')
			# e.g.: r12345 - command 'scripts/getver.sh' is not available in all revisions
			VERSION_OPENWRT="r$( git log -1 | grep 'git-svn-id' | cut -d'@' -f2 | cut -d' ' -f1 )"
		;;
		'trunk')
			$funcname 'switch_to_master'

			git pull
			scripts/feeds update

			log "$funcname() checkout local copy of trunk/$VERSION_OPENWRT"
			$funcname "$VERSION_OPENWRT"
		;;
		'r'*)
			$funcname 'switch_to_master'

			# typical entry:
			# git-svn-id: svn://svn.openwrt.org/openwrt/trunk@39864 3c298f89-4303-0410-b956-a3cf2f4a3e73
			hash="$( echo "$wish" | cut -b2- )"			# r12345 -> 12345  (remove leading 'r')
			hash="$( git log --format=%h --grep="@$hash " )"	# 12345 -> fe53cab (number -> hash)

			[ -z "$hash" ] && {
				# can happen if 'rXXXXX' is in packages/feeds, just use newest:
				hash="$( git log -1 --format=%h )"
			}

			git branch | grep -q ^"  openwrt@${hash}=${wish}"$ && {
				log "$funcname() removing old? branch 'openwrt@${hash}=${wish}'"
				git branch -D "openwrt@${hash}=${wish}"
			}

			git checkout -b "openwrt@${hash}=${wish}" "$hash" || {
				log "$funcname() checkout failed, trying to stash"
				git stash save "$funcname() going to checkout ${hash}=${wish}"

				git checkout -b "openwrt@${hash}=${wish}" "$hash" || {
					log "$funcname() checkout still failing, abort - see stash:" || {
						git stash list
						return 1
					}
				}
			}

			# r12345
			VERSION_OPENWRT="$wish"
		;;
		'switch_to_master')
			branch="$( git branch | grep ^'* openwrt@' | cut -d' ' -f2 )"
			if [ -n "$branch" ]; then
				log "$funcname() switching back to branch 'master'"
				# dont show which files have changed
				git checkout master >/dev/null
				log "$funcname() deleting branch '$branch'"
				git branch -D "$branch"
			else
				log "$funcname() already at branch 'master"
			fi

			# e.g.: r12345 - command 'scripts/getver.sh' is not available in all revisions
			VERSION_OPENWRT="r$( git log -1 | grep 'git-svn-id' | cut -d'@' -f2 | cut -d' ' -f1 )"

			[ -n "$( git stash list | grep -v '() going to checkout ' )" ] && {
				log "$funcname() found openwrt-stash, ignore via press 'q'"
				log "$funcname() or use e.g. 'git stash list OR pop OR apply stash@{0} OR clear"

				git stash list
			}
		;;
		*)
			log "$funcname() unknown option '$wish'"

			return 1
		;;
	esac

	return 0
}

copy_firmware_files()
{
	local funcname='copy_firmware_files'
	local attic="bin/$ARCH/attic"
	local file checksum rootfs server_dir
	local destination destination_scpsafe destination_info destination_info_scpsafa
	local error=0

	mkdir -p "$attic"
	rootfs="squash"

	log "kernel: '$VERSION_KERNEL'"
	log "openwrt-version: '$VERSION_OPENWRT'"
	log "hardware: '$HARDWARE_MODEL'"
	log "usecase = --usecase $LIST_OPTIONS"
	log "sysupgrade: '$FILENAME_SYSUPGRADE' in arch '$ARCH'"
	log "enforced_profile: $CONFIG_PROFILE"

	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_option=kalua@5dce00c,Standard,VDS_profile=liszt28.hybrid.4_rootfs=squash_image=sysupgrade.bin
	destination="$HARDWARE_MODEL_FILENAME"
	destination="${destination}.openwrt=${VERSION_OPENWRT}"
	destination="${destination}_kernel=${VERSION_KERNEL}"
	destination="${destination}_option=${LIST_OPTIONS}"
	[ -n "$CONFIG_PROFILE" ] && destination="${destination}_profile=${CONFIG_PROFILE}"
	destination="${destination}_rootfs=$rootfs"
	if [ -n "$CONFIG_PROFILE" ]; then
		destination="${destination}_image=factory"
	else
		destination="${destination}_image=sysupgrade"
	fi
	destination="${destination}.bin"

# hardware=	Ubiquiti Bullet M			// special, no option-name and separator='.'
# rootfs=	jffs2.64k | squash | ext4
# openwrt=	r38675
# kernel=	3.6.11
# image=	sysupgrade | factory | tftp | srec | ...
# profile=	liszt28.hybrid.4			// optional
# option=	Standard,kalua@5dce00c,VDS,failsafe,noIPv6,noPPPoE,micro,mini,small,LuCI ...

	if [ -n "$CONFIG_PROFILE" ]; then
		file="bin/$ARCH/$FILENAME_FACTORY"
	else
		file="bin/$ARCH/$FILENAME_SYSUPGRADE"
	fi

	if ls -l "$file"; then
		cp -v "$file" "$attic/$destination"
	else
		error=1
	fi

	log
	log "sysupgrade: '$FILENAME_SYSUPGRADE'"
	log "factory:    '$FILENAME_FACTORY'"

	if ls -l "bin/$ARCH/$FILENAME_FACTORY"; then
		:
	else
		error=1
	fi

	[ -n "$RELEASE" -a -e "$file" ] && {
		# workaround: when build without kalua
		[ -z "$LIST_OPTIONS_DOWNLOAD" ] && LIST_OPTIONS_DOWNLOAD="$LIST_OPTIONS"

		server_dir="${RELEASE_SERVER#*:}/models/$HARDWARE_MODEL_FILENAME/$RELEASE/$LIST_OPTIONS_DOWNLOAD"
		checksum="$( md5sum "$file" | cut -d' ' -f1 )"

		cat >'info.txt' <<EOF
# server: $( hostname )
# build at: $( TZ='CET-1CEST-2,M3.5.0/02:00:00,M10.5.0/03:00:00' date )
# build time: $BUILD_DURATION sec

file='$destination' checksum_md5='$checksum'
EOF
		destination="$RELEASE_SERVER/models/$HARDWARE_MODEL_FILENAME/$RELEASE/$LIST_OPTIONS_DOWNLOAD/$destination"
		destination_scpsafe="$( echo "$destination" | sed 's| |\\\\ |g' )"	# 'a b' -> 'a\\ b'
		destination_info="$RELEASE_SERVER/models/$HARDWARE_MODEL_FILENAME/$RELEASE/$LIST_OPTIONS_DOWNLOAD/info.txt"
		destination_info_scpsafe="$( echo "$destination_info" | sed 's| |\\\\ |g' )"

		# readme.md?
		# tarball?

		log "ssh \"${RELEASE_SERVER%:*}\" \"mkdir -p '$server_dir'\""
		ssh "${RELEASE_SERVER%:*}" "mkdir -p '$server_dir'"
		log  "scp '$file' '$destination_scpsafe'"
		echo "scp '$file' '$destination_scpsafe'"		 >'DO_SCP.sh'
		echo "scp 'info.txt' '$destination_info_scpsafe'"	>>'DO_SCP.sh'

		# a direct call fails with 'scp: ambiguous target'
		. './DO_SCP.sh' && rm 'DO_SCP.sh' 'info.txt'

		error=0
	}

	return $error
}

build()
{
	local funcname='build'
	local option="$1"
	local cpu_count="$( grep -c ^'processor' '/proc/cpuinfo' )"
	local jobs=$(( $cpu_count + 1 ))
	local commandline="--jobs $jobs"
	local verbose t1 t2 rest
	[ -n "$DEBUG" ] && verbose='V=s'

	case "$option" in
		'nuke_bindir')
			log "$funcname() $option: removing unneeded firmware/packages, but leaving 'attic'-dir"
			rm     "bin/$ARCH/"*	    2>/dev/null
			rm -fR "bin/$ARCH/packages" 2>/dev/null
		;;
		'defconfig')
			log "$funcname() running 'make defconfig'" debug

			make $verbose defconfig >/dev/null || make defconfig
		;;
		*)
			log "$funcname() running 'make $commandline'"
			read t1 rest </proc/uptime
			make $verbose $commandline
			read t2 rest </proc/uptime
			BUILD_DURATION=$(( ${t2%.*}${t2#*.} - ${t1%.*}${t1#*.} ))
			BUILD_DURATION=$(( $BUILD_DURATION / 100 )).$(( $BUILD_DURATION % 100 ))
			log "$funcname() running 'make $commandline' lasts $BUILD_DURATION sec"
		;;
	esac
}

apply_symbol()
{
	local funcname='apply_symbol'
	local symbol="$1"
	local file='.config'
	local custom_dir='files'	# standard way to add/customize
	local choice hash tarball_hash
	local last_commit_unixtime last_commit_date url hash
	local file installation sub_profile node
	local dir basedir pre

	case "$symbol" in
		"$KALUA_DIRNAME"*)
			log "$funcname() $KALUA_DIRNAME: getting files"

			# is a short hash, e.g. 'ed0e11ci', this is enough:
			# http://lkml.indiana.edu/hypermail/linux/kernel/1309.3/04147.html
			cd $KALUA_DIRNAME
			VERSION_KALUA="$( git log -1 --format=%h )"
			last_commit_unixtime="$( git log -1 --pretty=format:%ct )"
			last_commit_unixtime_in_hours=$(( $last_commit_unixtime / 3600 ))
			last_commit_date="$( date -d @$last_commit_unixtime )"

			case "$symbol" in
				"$KALUA_DIRNAME@"*)
					# can be a short or a long-hash -> convert to short
					hash="$( echo "$symbol" | cut -d'@' -f2 )"
					hash="$( git rev-parse --short "$hash" )"

					case "$hash" in
						"$VERSION_KALUA"*)
							hash=
						;;
						*)
							git checkout -b "$KALUA_DIRNAME@$hash" "$hash"
							VERSION_KALUA="$hash"
						;;
					esac
				;;
			esac

			LIST_OPTIONS_DOWNLOAD="${LIST_OPTIONS}${LIST_OPTIONS+,}$KALUA_DIRNAME"
			LIST_OPTIONS="${LIST_OPTIONS_DOWNLOAD}@$VERSION_KALUA"

			cd ..
			log "$funcname() $KALUA_DIRNAME: adding ${KALUA_DIRNAME}-files @$VERSION_KALUA to custom-dir '$custom_dir/'"
			cp -R "$KALUA_DIRNAME/openwrt-addons/" "$custom_dir"

			log "$funcname() $KALUA_DIRNAME: adding 'apply_profile' stuff to '$custom_dir/etc/init.d/'"
			cp "$KALUA_DIRNAME/openwrt-build/apply_profile"* "$custom_dir/etc/init.d"

			log "$funcname() $KALUA_DIRNAME: adding version-information = '$last_commit_date'"
			echo  >'files/etc/variables_fff+' "FFF_PLUS_VERSION=$last_commit_unixtime_in_hours	# $last_commit_date"
			echo >>'files/etc/variables_fff+' "FFF_VERSION=2.0.0			# OpenWrt based / unused"

			log "$funcname() $KALUA_DIRNAME: adding hardware-model to 'files/etc/HARDWARE'"
			echo >'files/etc/HARDWARE' "$HARDWARE_MODEL"

			log "$funcname() $KALUA_DIRNAME: tweaking kernel commandline"
			kernel_commandline_tweak

			log "$funcname() $KALUA_DIRNAME: apply_wifi_reghack"
			apply_wifi_reghack

			# http://stackoverflow.com/questions/1018853/why-is-alloca-not-considered-good-practice
			#
			# no-caller-saves:
			# http://gcc.gnu.org/onlinedocs/gccint/Caller-Saves.html
			#
			# stack-check / stack-protector / stack-protector-all / stack-protector-strong / ssp-buffer-size:
			# http://stackoverflow.com/questions/2369886/how-does-the-gcc-option-fstack-check-exactly-work
			# http://gcc.gnu.org/onlinedocs/gccint/Stack-Checking.html
			# http://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#Optimize-Options
			# http://www.research.ibm.com/trl/projects/security/ssp/
			# http://www.phrack.org/issues.html?issue=49&id=14#article
			#
			# no-delete-null-pointer-checks:
			# http://www.chromium.org/chromium-os/chromiumos-design-docs/system-hardening
			#
#			log "$funcname() $KALUA_DIRNAME: compiler tweaks"
#			apply_symbol 'CONFIG_DEVEL=y'		# 'Advanced configuration options'
#			apply_symbol 'CONFIG_EXTRA_OPTIMIZATION="-fno-caller-saves -fstack-protector -fstack-protector-all -fno-delete-null-pointer-checks"'

			url="http://intercity-vpn.de/firmware/$ARCH/images/testing/info.txt"
			log "$funcname() $KALUA_DIRNAME: adding recent tarball hash from '$url'"
			tarball_hash="$( wget -qO - "$url" | fgrep 'tarball.tgz' | cut -d' ' -f2 )"
			if [ -z "$tarball_hash" ]; then
				log "$funcname() cannot fetch tarball hash, be prepared that node will automatically update upon first boot"
			else
				echo >'files/etc/tarball_last_applied_hash' "$tarball_hash"
			fi

			if [ -e '/tmp/apply_profile.code.definitions' ]; then
				log "$funcname() $KALUA_DIRNAME: using custom '/tmp/apply_profile.code.definitions'"
				cp '/tmp/apply_profile.code.definitions' "$custom_dir/etc/init.d"
			else
				log "$funcname() $KALUA_DIRNAME: no '/tmp/apply_profile.code.definitions' found, using standard $KALUA_DIRNAME file"
			fi

			basedir="$KALUA_DIRNAME/openwrt-patches/add2trunk"
			log "$funcname() $KALUA_DIRNAME: adding private patchsets from $basedir"
			for dir in $basedir/*; do {
				[ -d "$dir" ] || continue

				log "$funcname() $KALUA_DIRNAME: adding patchset '$( basename "$dir" )'"

				for file in $dir/*; do {
					# http://stackoverflow.com/questions/15934101/applying-a-diff-file-with-git
					git rebase --abort
					git am --abort
					git am --signoff <"$file" || log "$funcname() ERROR during 'git am <$file'"
				} done
			} done

			[ -n "$CONFIG_PROFILE" ] && {
				file="$custom_dir/etc/init.d/apply_profile.code"
				installation="$( echo "$CONFIG_PROFILE" | cut -d'.' -f1 )"
				sub_profile="$(  echo "$CONFIG_PROFILE" | cut -d'.' -f2 )"
				node="$(         echo "$CONFIG_PROFILE" | cut -d'.' -f3 )"

				log "$funcname() $KALUA_DIRNAME: enforced profile: $installation - $sub_profile - $node"
				sed -i "s/^#SIM_ARG1=/SIM_ARG1=$installation    #/" "$file"
				sed -i "s/^#SIM_ARG2=/SIM_ARG2=$sub_profile    #/" "$file"
				sed -i "s/^#SIM_ARG3=/SIM_ARG3=$node    #/" "$file"
				sed -i 's|^#\[ "$SIM_ARG3|\[ "$SIM_ARG3|' "$file"	# wan-dhcp for node 2
			}

			[ -n "$hash" ] && {
				cd $KALUA_DIRNAME
				git checkout master
				git branch -D "$KALUA_DIRNAME@$hash"
				cd ..
			}

			return 0
		;;
		'nuke_customdir')
			log "$funcname() deleting dir for custom files: '$custom_dir/'"
			rm -fR "$custom_dir"

			return 0
		;;
		'kernel')
			log "$funcname() not implemented yet '$kernel' -> $2"
			return 0
			# target/linux/ar71xx/config-3.10
		;;
		'nuke_config')
			log "$funcname() $symbol: starting with an empty config"
			rm "$file"
			touch "$file"

			$funcname 'nuke_customdir'
			build 'nuke_bindir'

			return 0
		;;
		'CONFIG_PACKAGE_ATH_DEBUG=y')
			# only when atheros-drivers are involved
			grep -q 'CONFIG_PACKAGE_kmod-ath=y' "$file" || return 0
		;;
	esac

	case "$symbol" in
		*'=y'|*' is not set')
			log "$funcname() symbol: $symbol" debug
		;;
		*)
			log "$funcname() symbol: $symbol"
		;;
	esac

	case "$symbol" in
		*'=y')
			symbol="$( echo "$symbol" | cut -d'=' -f1 )"

			if grep -sq ^"# $symbol is not set" "$file"; then
				sed -i "s/^# $symbol is not set/${symbol}=y/" "$file"
			else
				grep -sq "$symbol" "$file" || echo >>"$file" "$symbol=y"
			fi
		;;
		*' is not set')
			set -- $symbol
			symbol="$1"

			if grep -sq ^"$symbol=y" "$file"; then
				sed -i "s/^${symbol}=y/# $symbol is not set/" "$file"
			else
				grep -sq "$symbol" "$file" || echo >>"$file" "# $@"
			fi
		;;
		'CONFIG_'*)
			# e.g. CONFIG_B43_FW_SQUASH_PHYTYPES="G"
			grep -sq ^"$symbol"$ "$file" || {
				pre="$( echo "$symbol" | cut -d'=' -f1 )"

				grep -q "$pre" "$file" && {
					# remove symbol
					sed -i "/${pre}=.*/d" "$file"
				}

				echo "$symbol" >>"$file"
			}
		;;
	esac
}

serialize_comma_list()
{
	local oldIFS="$IFS"; IFS=','; set -- $1; IFS="$oldIFS"

	echo "$@"
}

build_options_set()
{
	local funcname='build_options_set'
	local options="$1"
	local subcall="$2"
	local file='.config'
	local custom_dir='files'

	# shift args, because the call is: $funcname 'subcall' "$opt"
	[ "$options" = 'subcall' -a -n "$subcall" ] && options="$subcall"

	set -- $( serialize_comma_list "$options" )
	while [ -n "$1" ]; do {
		log "$funcname() apply '$1' $( test -n "$subcall" && echo -n "(subcall)" )"

		# build a comma-separated list for later output/build-documentation
		case "${subcall}-$1" in
			"-$KALUA_DIRNAME"*)	# parser_ignore
						# direct call to kalua (no subcall)
			;;
			'-'*)	# parser_ignore
				# direct call (no subcall)
				LIST_OPTIONS="${LIST_OPTIONS}${LIST_OPTIONS+,}${1}"
			;;
		esac

		case "$1" in
			'defconfig')
				# this simply adds or deletes no symbols
			;;
			"$KALUA_DIRNAME")
				apply_symbol "$1"
			;;
			"$KALUA_DIRNAME@"*)	# parser_ignore
				apply_symbol "$1"
			;;
			'Standard')	# >4mb flash
				apply_symbol 'CONFIG_PACKAGE_zram-swap=y'		# base-system: zram-swap
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_ip=y'			# network: routing/redirection: ip
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g
				apply_symbol 'CONFIG_PACKAGE_mii-tool=y'		# network: mii-tool:
				apply_symbol 'CONFIG_PACKAGE_rrdtool=y'			# utilities: rrdtool:
				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless:
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools

				$funcname subcall 'shaping'
				$funcname subcall 'vtun'
				$funcname subcall 'mesh'
				$funcname subcall 'noFW'
			;;
			'Small')	# <4mb flash - for a working jffs2 it should not exceed '3.670.020' bytes (e.g. WR703N)
				apply_symbol 'CONFIG_PACKAGE_zram-swap=y'		# base-system: zram-swap
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_ip=y'			# network: routing/redirection: ip
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
#				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
#				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g
#				apply_symbol 'CONFIG_PACKAGE_tc=y'			# network: tc
				apply_symbol 'CONFIG_PACKAGE_mii-tool=y'		# network: mii-tool: (very small)
#				apply_symbol 'CONFIG_PACKAGE_rrdtool=y'			# utilities: rrdtool:
#				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless: (but debugFS-export still active)
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
#				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools
#
#				$funcname subcall 'vtun'
#				$funcname subcall 'mesh'
				$funcname subcall 'noFW'
			;;
			'Mini')
				# be careful: getting firmware and reflash must be possible (or bootloader with TFTP needed)
				# like small and: noMESH, noSSH, noOPKG, noSwap, noUHTTPD, noIPTables
				# -coredump,-debug,-symbol-table
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# kernel-modules: wireless:

				$funcname subcall 'noFW'
				$funcname subcall 'noIPv6'
				$funcname subcall 'noPPPoE'
			;;
			'Micro')
				# like mini and: noWiFi, noDNSmasq, noJFFS2-support?
			;;
			### here starts all functions/packages, above are 'meta'-descriptions ###
			'USBprinter')
				apply_symbol 'CONFIG_PACKAGE_p910nd=y'			# network: printing: p910
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-printer=y'	# kernel-modules: other: kmod-usb-printer
			;;
			'Bluetooth')
				apply_symbol 'CONFIG_PACKAGE_bluez-utils=y'		# utilities: bluez-utils
				apply_symbol 'CONFIG_PACKAGE_bluez-hcidump=y'		# utilities: bluez-hcidump
				apply_symbol 'CONFIG_PACKAGE_kmod-bluetooth=y'		# kmodules: others: bluetooth
			;;
			'BTCminerBFL')
				# for now its hardcoded to '--enable-bflsc' / Butterfly ASIC
				apply_symbol 'CONFIG_PACKAGE_cgminer=y'			# utilities: cgminer
			;;
			'BTCminerCPU')
				# copy_additional_packages() will tweak the Makefile
				apply_symbol 'CONFIG_PACKAGE_cgminer=y'			# utilities: cgminer
			;;
			'shaping')
				apply_symbol 'CONFIG_PACKAGE_kmod-sched=y'		# kernel-modules: network support: kmod-sched
				apply_symbol 'CONFIG_PACKAGE_tc=y'			# network: tc
			;;
			'b43mini')
				apply_symbol 'CONFIG_B43_FW_SQUASH_PHYTYPES="G"'	# kernel-modules: wireless: b43
				apply_symbol 'CONFIG_PACKAGE_B43_PHY_N is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_B43_PHY_HT is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_kmod-b43legacy is not set'	# kernel-modules:
			;;
			'Arduino')
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-acm=y'		# kernel-modules: USB-support
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-serial=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-serial-ftdi=y'
			;;
			'BigBrother')
				apply_symbol 'CONFIG_PACKAGE_kmod-video-core=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-video-uvc=y'
				apply_symbol 'CONFIG_PACKAGE_ffmpeg=y'
				apply_symbol 'CONFIG_PACKAGE_motion=y'
				apply_symbol 'CONFIG_PACKAGE_v4l-utils=y'
			;;
			'DSLR')	# http://en.wikipedia.org/wiki/Digital_single-lens_reflex_camera
				apply_symbol 'CONFIG_PACKAGE_gphoto2=y'			# multimedia
				apply_symbol 'CONFIG_PACKAGE_libgphoto2-drivers'	# libraries
			;;
			'USBaudio')
				apply_symbol 'CONFIG_PACKAGE_madplay=y'			# sound: madplay
				apply_symbol 'CONFIG_PACKAGE_kmod-sound-core=y'		# kernel-modules: sound:
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-audio=y'		# ...
#				apply_symbol 'CONFIG_PACKAGE_kmod-input-core=y'		# ...
			;;
			'LuCI')
				apply_symbol 'CONFIG_PACKAGE_luci-mod-admin-core=y'	# LuCI: modules
			;;
			'LuCIfull')
				apply_symbol 'CONFIG_PACKAGE_luci=y'			# LuCI: collections
			;;
			'vtun')
				apply_symbol 'CONFIG_PACKAGE_vtun=y'			# network: vpn: vtun:
				apply_symbol 'CONFIG_VTUN_SSL is not set'		# ...
			;;
			'mesh')
				$funcname subcall 'OLSRd'
				$funcname subcall 'BatmanAdv'
			;;
			'OLSRd')
				apply_symbol 'CONFIG_PACKAGE_olsrd=y'			# network: routing/redirection: olsrd:
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-nameservice=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-txtinfo=y'	# ...
			;;
			'BatmanAdv')
				apply_symbol 'CONFIG_PACKAGE_kmod-batman-adv=y'		# kernel-modules: support: batman-adv

				$funcname subcall 'ebTables'
				$funcname subcall 'macVLAN'
			;;
			'macVLAN')
				apply_symbol 'CONFIG_PACKAGE_kmod-macvlan=y'		# kernel-modules: network-devices:
			;;
			'ebTables')
				apply_symbol 'CONFIG_PACKAGE_ebtables=y'		# # network: firewall: ebtables
			;;
			'VDS')
				apply_symbol 'CONFIG_PACKAGE_ulogd=y'			# network: ulogd:
				apply_symbol 'CONFIG_PACKAGE_ulogd-mod-extra=y'		# ...
			;;
			### here starts all 'no'-thingys: remove stuff which is on by OpenWrt-default
			'noIPv6')
				# seems not to work with brcm47xx, but with ar71xx?! -> see 'DEFAULT's
				$funcname subcall 'noFW'

				# CONFIG_PACKAGE_libip6tc=y
				# CONFIG_PACKAGE_libxtables=y
				# CONFIG_DEFAULT_6relayd=y
				# CONFIG_DEFAULT_ip6tables=y
				# CONFIG_DEFAULT_odhcp6c=y

				apply_symbol 'CONFIG_IPV6 is not set'			# global build settings: IPv6 support in packages
				apply_symbol 'CONFIG_PACKAGE_6relayd is not set'	# network: 6relayd
				apply_symbol 'CONFIG_PACKAGE_odhcp6c is not set'	# network: odhcp6c
				apply_symbol 'CONFIG_PACKAGE_odhcpd is not set'		# network: odhcpd
				apply_symbol 'CONFIG_PACKAGE_kmod-ip6tables is not set'	# kernel-modules: netfilter-extensions: ip6tables
				apply_symbol 'CONFIG_PACKAGE_kmod-ipv6 is not set'	# kernel-modules: network-support: kmod-ipv6
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_IPV6 is not set'	# base/busybox/networking/ipv6-support
			;;
			'noPPPoE')
				apply_symbol 'CONFIG_PACKAGE_ppp is not set'		# network: ppp
				apply_symbol 'CONFIG_PACKAGE_kmod-ppp is not set'	# kernel-modules: network-support: ppp
				apply_symbol 'CONFIG_PACKAGE_kmod-pppoe is not set'	# needed?
				apply_symbol 'CONFIG_PACKAGE_kmod-pppox is not set'	# needed?
			;;
			'noPrintK')
				apply_symbol kernel 'CONFIG_PRINTK is not set'		# general setup: standard kernel features
				apply_symbol kernel 'CONFIG_EARLY_PRINTK is not set'	# kernel hacking: early printk
				apply_symbol kernel 'CONFIG_SYS_HAS_EARLY_PRINTK is not set'
			;;
			'noSwap')
				apply_symbol kernel 'CONFIG_SWAP is not set'		# general setup: Support for anon mem
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_SWAPONOFF is not set'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_MKSWAP is not set'
			;;
			'noFW')
				apply_symbol 'CONFIG_PACKAGE_firewall is not set'	# base-system: firewall3 *off*
				apply_symbol 'CONFIG_DEFAULT_firewall is not set'	# needed?
			;;
			# help/usage-function
			'list')
				[ "$subcall" = 'plain' ] || log "$funcname() supported options:"

				parse_case_patterns "$funcname" | while read line; do {
					if [ "$subcall" = 'plain' ]; then
						echo "$line"
					else
						echo "--usecase $line"
					fi
				} done

				[ "$subcall" = 'plain' ] || {
					echo
					echo '# or short:'

					echo -n '--usecase '
					parse_case_patterns "$funcname" | while read line; do {
						echo -n "$line,"
					} done
					echo
				}

				return 1
			;;
			*)
				log "$funcname() unknown option '$1'"

				return 1
			;;
		esac

		build 'defconfig'
		shift
	} done

	[ -n "$subcall" ] || {
		log "$funcname() adding build-information '$LIST_OPTIONS' to '$custom_dir/etc/openwrt_build'"
		mkdir -p "$custom_dir/etc"
		echo "$LIST_OPTIONS" >"$custom_dir/etc/openwrt_build"
	}
}

parse_case_patterns()
{
	local fname="$1"		# function to parse
	local start_parse line temp

	while read line; do {
		if [ "$start_parse" = 'true' ]; then
			case "$line" in
				*')'*)
					case "$line" in
						*'# parser_ignore'*)
							continue
						;;
					esac

					local oldIFS="$IFS"; IFS='|'; set -- $line; IFS="$oldIFS"
					while [ -n "$1" ]; do {
						case "$1" in
							"'list')")
								# parser at end of the function
								return 1
							;;
							'"'*)
								temp="$( echo "$@" | cut -d'"' -f2 )"

								case "$temp" in
									'$'*)
										eval echo "$temp"
									;;
									*)
										echo "$temp"
									;;
								esac
							;;
							"'"*)
								echo "$@" | cut -d"'" -f2
							;;
						esac

						shift
					} done
				;;
				'}')
					return 0
				;;
			esac
		else
			case "$line" in
				"$fname()"*)
					# parser at begin of the function
					start_parse='true'
				;;
			esac
		fi
	} done <"$0"
}

check_git_settings()
{
	local funcname='check_git_settings'

	git config --global user.email >/dev/null || {
		log "$funcname() please set: git config --global user.email 'your@email.tld'"
		return 1
	}

	git config --global user.name  >/dev/null || {
		log "$funcname() please set: git config --global user.name 'Your Name'"
		return 1
	}
}

# kalua/openwrt-build/build.sh      -> kalua
# weimarnetz/openwrt-build/build.sh -> weimarnetz
KALUA_DIRNAME="$( echo "$0" | cut -d'/' -f1 )"

while [ -n "$1" ]; do {
	case "$1" in
		'--help'|'-h')
			print_usage_and_exit
		;;
		'--force'|'-f')
			FORCE='true'
		;;
		'--openwrt')
			VERSION_OPENWRT="$2"
		;;
		'--kernel'|'-k')
			VERSION_KERNEL_FORCE="$2"
		;;
		'--hardware'|'-hw')
			if target_hardware_set 'list' 'plain' | grep -q ^"$2"$ ; then
				HARDWARE_MODEL="$2"
			else
				# e.g. option 'plain'
				target_hardware_set 'list' "$3"
				exit 1
			fi
		;;
		'--usecase'|'-u')
			for LIST_USER_OPTIONS in $( serialize_comma_list "${2:-help}" ); do {
				if build_options_set 'list' 'plain' | grep -q ^"$( echo "$LIST_USER_OPTIONS" | cut -d'@' -f1 )"$ ; then
					LIST_USER_OPTIONS="$2"
				else
					log "problem for argument '$LIST_USER_OPTIONS'"
					build_options_set 'list' "$3"
					exit 1
				fi
			} done
		;;
		'--profile'|'-p')
			# e.g. ffweimar.hybrid.120
			CONFIG_PROFILE="$2"
		;;
		'--release'|'-r')
			case "$2" in
				'stable'|'beta'|'testing')
					RELEASE="$2"
					RELEASE_SERVER="$3"
				;;
				*)
					log "[ERR] --release stable|beta|testing"
					exit 1
				;;
			esac
		;;
		'--debug'|'-d'|'--verbose'|'-v')
			log "[OK] mode DEBUG / VERBOSE activated"
			DEBUG='true'
		;;
		'--quiet'|'-q')
			QUIET='true'
		;;
	esac

	shift
} done

die_and_exit()
{
	[ -n "$FORCE" ] && return 0

	log
	log '[ERROR] the brave can try --force'
	exit 1
}

check_git_settings			|| die_and_exit
check_working_directory			|| die_and_exit
openwrt_download "$VERSION_OPENWRT"	|| die_and_exit

[ -z "$HARDWARE_MODEL" ]    && print_usage_and_exit "you forgot to specifiy --hardware '\$MODEL'"
[ -z "$LIST_USER_OPTIONS" ] && print_usage_and_exit "you forgot to specifiy --usecase '\$USECASE'"

target_hardware_set "$HARDWARE_MODEL"	|| die_and_exit
copy_additional_packages		|| die_and_exit
build_options_set "$LIST_USER_OPTIONS"	|| die_and_exit
build					|| exit 1
copy_firmware_files			|| die_and_exit
openwrt_download 'switch_to_master'

log "[OK]"
exit 0
