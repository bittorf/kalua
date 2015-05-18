#!/bin/sh

# ToDo:
# - autoremove old branches: for B in $(git branch|grep @); do git branch -D $B; done
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

print_usage_and_exit()
{
	local hint="$1"
	local rev="$( openwrt_revision_number_get )"
	local hardware usecase more_options

	if [ -e 'files/etc/HARDWARE' ]; then
		# last used one
		read hardware <'files/etc/HARDWARE'
	else
		hardware="$( target_hardware_set 'list' 'plain' | head -n1 )"
	fi

	if [ -e 'files/etc/openwrt_build' ]; then
		# last used one, e.g.: Standard,noPPPoE,BigBrother,kalua@e678dd6
		read usecase <'files/etc/openwrt_build'
		usecase="$( echo "$usecase" | cut -d'@' -f1 )"
	else
		usecase="Standard,$KALUA_DIRNAME"
	fi

	[ -e ~/whoami -a -e ~/hostname ] && {
		more_options="--buildid '$( tail -n1 ~/whoami | cut -d' ' -f2 )@$( tail -n1 ~/hostname | cut -d' ' -f2 )'"
	}

	[ -n "$hint" ] && log "[HINT:] $hint"

	if [ -e 'build.sh' ]; then
		cat <<EOF

Usage: sh $0 --openwrt
       (this will download/checkout OpenWrt)
EOF
	else
		cat <<EOF

Usage: $0 --openwrt <revision> --hardware <model> --usecase <meta_names>
       $0 --debug --${KALUA_DIRNAME}_package

e.g. : $0 --openwrt r${rev:-12345} --hardware '$hardware' --usecase '$usecase' $more_options

Get help without args, e.g.: --hardware <empty>
EOF

#	--patchdir \$dir
#       --openwrt trunk | <empty>
#	--hardware 'Ubiquiti Bullet M5'|<empty> = list supported models
#	--buildid 'user@domain.tld'
#	--kernel
#	--usecase
#	--profile 'ffweimar.hybrid.120'
#	--release 'stable' 'user@server:/your/path'	# copy sysupgrade-file without all details = 'Ubiquiti Bullet M.sysupgrade.bin'
#	--debug
#	--force
#	--quiet
	fi

	test -n "$FORCE"
	exit $?
}

build_tarball_package()
{
	local funcname='build_tarball_package'

	[ "$KALUA_DIRNAME" = 'openwrt-build' ] && {
		log "wrong path, i dont want to see 'openwrt-build'"
		return 1
	}

	local architecture='all'
	local package_name="$KALUA_DIRNAME-framework"
	local kalua_unixtime="$( cd kalua; git log -1 --pretty='format:%ct'; cd .. )"
	local package_version="$(( $kalua_unixtime / 3600 ))"
	local file_tarball="${package_name}_${package_version}_${architecture}.ipk"

	local url='https://github.com/bittorf/kalua'		# TODO: ffweimar?
	local builddir="$KALUA_DIRNAME/builddir"
	local destdir="bin/${ARCH:-$architecture}/packages"
	local verbose="${DEBUG+v}"
	local tar_flags="-c${verbose}zf"
	local tar_options='--owner=root --group=root'

	mkdir "$builddir" || return 1
	cd "$builddir"

	echo '2.0' >'debian-binary'

	cat >'control' <<EOF
Package: $package_name
Priority: optional
Version: $package_version
Maintainer: Bastian Bittorf <kontakt@weimarnetz.de>
Section: utils
Description: some helper scripts for making debugging easier on meshed openwrt nodes
Architecture: $architecture
Source: $url
EOF

	tar $tar_options $tar_flags 'control.tar.gz' ./control
	tar $tar_options $tar_flags 'data.tar.gz' -C ../openwrt-addons $( ls -1 ../openwrt-addons )
	tar $tar_options $tar_flags "$file_tarball" ./debian-binary ./control.tar.gz ./data.tar.gz
	rm 'control' 'debian-binary'

	cd ..
	cd ..

	log "moving '$file_tarball' from dir '$builddir' to '$destdir'"
	mkdir -p "$destdir"
	mv "$builddir/$file_tarball" "$destdir"
}

log()
{
	local message="$1"
	local option="$2"	# e.g. debug,gitadd
	local gitfile="$3"	# can also be a directory
	local name

	has()
	{
		local list="$1"
		local keyword="$2"

		case ",$list," in               # e.g. debug,gitadd
			*",$keyword,"*)
				return 0
			;;
			*)
				return 1
			;;
		esac
	}

	has "$option" 'gitadd' && {
		git branch | grep -q ^'* master' || {
			log "[ERR] warning: autocommit on master"
		}

		git add "$gitfile"
		git commit --signoff -m "autocommit:
file: $gitfile
$message

git-svn-id: based_on@$( echo "$VERSION_OPENWRT" | sed 's/r//' )	# mimics OpenWrt-style
"
	}

	case "$funcname" in
		'')
		;;
		'quiet_'*)
			return 0
		;;
		*)
			name=" $funcname()"
		;;
	esac

	[ -n "$QUIET" ] && return 0
	has "$option" 'debug' && test -z "$DEBUG" && return 0

	case "$message" in
		*'[ERROR]'*)
			logger -p user.info -s '! \'
			logger -p user.info -s "!  )- $0: $message"
			logger -p user.info -s '! /'
		;;
		*)
			logger -p user.info -s "$0:$name $message"
		;;
	esac
}

kernel_commandline_tweak()	# https://lists.openwrt.org/pipermail/openwrt-devel/2012-August/016430.html
{
	local funcname='kernel_commandline_tweak'
	local dir="target/linux/$ARCH"
	local pattern=" oops=panic panic=10 "
	local config kernelversion

	case "$ARCH" in
		mpc85xx)
			# config-3.10 -> 3.10
			kernelversion="$( ls -1 $dir/config-* | head -n1 | cut -d'-' -f2 )"
			config="$dir/patches-$kernelversion/140-powerpc-85xx-tl-wdr4900-v1-support.patch"

			fgrep -q "$pattern" "$config" || {
				sed -i "s/console=ttyS0,115200/$pattern &/" "$config"
				log "looking into '$config', adding '$pattern'" gitadd "$config"
			}
		;;
		ar71xx)
			config="$dir/image/Makefile"

			fgrep -q "$pattern" "$config" || {
				sed -i "s/console=/$pattern &/" "$config"
				log "looking into '$config', adding '$pattern'" gitadd "$config"
			}
		;;
		*)	# tested for brcm47xx
			config="$( ls -1 $dir/config-* 2>/dev/null | head -n1 )"

			if [ -e "$config" ]; then
				log "looking into '$config', adding '$pattern'"

				fgrep -q "$pattern" "$config" || {
					sed -i "/^CONFIG_CMDLINE=/s/\"$/${pattern}\"/" "$config"
					log "looking into '$config', adding '$pattern'" gitadd "$config"
				}
			else
				log "cannot find '$config' from '$dir/config-*'"
			fi
		;;
	esac
}

register_patch()
{
	local funcname='register_patch'
	local name="$1"
	local dir='files/etc'
	local file="$dir/openwrt_patches"	# we can read the file later on the router

	if [ -f "$name" ]; then
		name="$( basename "$name" )"
	else
		case "$name" in
			'CONFIG_'*)
				return 0
			;;
			'FAILED: '*)
				set -- $name
				shift
				name="$( basename "$@" )"
				name="* failed: $name"
			;;
		esac
	fi

	if [ "$name" = 'init' ]; then
		[ -e "$file" ] && rm "$file"
	else
		case "$name" in
			'DIR:'*|*':'|'REGHACK:'*)	# FIXME!
				# directory
				name="=== $name ==="
			;;
			*)
				# individual files, e.g.
				# 0004-base-files-hotplug-call-minor-optimization-use-shell.patch
				name="  $name"
			;;
		esac

		[ -d "$dir" ] || mkdir "$dir"

		grep -sq ^"$name"$ "$file" || {
			[ -e "$name" ] && log "adding patchfile" gitadd "$name"
			echo "$name" >>"$file"
		}
	fi
}

apply_minstrel_rhapsody()	# successor of minstrel -> minstrel_blues: http://www.linuxplumbersconf.org/2014/ocw/sessions/2439
{
	local funcname='apply_minstrel_rhapsody'
	local dir='kalua/openwrt-patches/interesting/minstrel-rhapsody'
	local kernel_dir='package/kernel/mac80211'
	local file base

	MAC80211_CLEAN='true'
	register_patch "DIR: $dir"

	register_patch $dir/Makefile
	cp $dir/Makefile $kernel_dir
	git add $kernel_dir/Makefile

	for file in $dir/patches/*; do {
		register_patch "$file"
		cp $file $kernel_dir/patches
		git add $kernel_dir/patches/$( basename "$file" )
	} done

	# TODO: use log()
	git commit --signoff -m "$funcname()"
}

apply_wifi_reghack()		# maybe unneeded with r45252
{
	local funcname='apply_wifi_reghack'
	local option="$1"	# e.g. 'disable'
	local file='kalua/openwrt-patches/reghack/900-regulatory-compliance_test.patch'
	local file_regdb_hacked countries code
	local COMPAT_WIRELESS="2013-06-27"

	[ -e "$file" ] && {
		MAC80211_CLEAN='true'

		if grep -q "${option}CONFIG_PACKAGE_kmod-ath9k=y" ".config"; then
			log "patching ath9k/compat-wireless $COMPAT_WIRELESS for using all channels ('birdkiller-mode')"

			cp -v "$file" "package/kernel/mac80211/patches"
			sed -i "s/YYYY-MM-DD/${COMPAT_WIRELESS}/g" "package/kernel/mac80211/patches/$( basename "$file" )"

			if [ "$( echo "$VERSION_OPENWRT" | cut -b2- )" -lt 40293 ]; then
				file_regdb_hacked='kalua/openwrt-patches/reghack/regulatory.db.txt'
			else
				file_regdb_hacked='kalua/openwrt-patches/reghack/regulatory.db.txt-r40293++'
			fi

			log "using another regdb: '$file_regdb_hacked'"
			cp "package/kernel/mac80211/files/regdb.txt" "package/kernel/mac80211/files/regdb.txt_original"
			cp -v "$file_regdb_hacked" "package/kernel/mac80211/files/regdb.txt"

			# e.g. '00 US FM'
			countries="$( grep ^'country ' "$file_regdb_hacked" | cut -d' ' -f2 | cut -d':' -f1 )"
			countries="$( echo "$countries" | while read code; do echo -n "$code "; done )"		# remove CR/LF

			register_patch "REGHACK: valid countries: $countries"
			register_patch "$file"
			register_patch "$file_regdb_hacked"
		else
			file="$( basename "$file" )"

			[ -e "package/kernel/mac80211/files/regdb.txt_old" ] && {
				cp -v "package/kernel/mac80211/files/regdb.txt_original" "package/kernel/mac80211/files/regdb.txt"
			}

			[ -e "package/kernel/mac80211/patches/$file" ] && {
				rm -v "package/kernel/mac80211/patches/$file"
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

			do_copy()
			{
				log "working on '$dir', destination: '$install_section'"
				cp -Rv "$dir" "package/$install_section"
				log "whole dir" gitadd "package/$install_section"
			}

			if [ "$package" = 'cgminer' ]; then
				case "$LIST_USER_OPTIONS" in
					*'BTCminerCPU'*)
						do_copy

						file="package/$install_section/$package/Makefile"
						sed -i 's/PKG_REV:=.*/PKG_REV:=1a8bfad0a0be6ccbb2cc88917d233ac5db08a02b/' "$file"
						sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=2.11.3/' "$file"
						sed -i 's/--enable-bflsc/--enable-cpumining/' "$file"
						log "cgminer" gitadd "$file"
					;;
				esac
			else
				do_copy
			fi
		else
			log "no Makefile found in '$dir' - please check"
			return 0
		fi
	} done

	return 0
}

target_hardware_set()
{
	local funcname='target_hardware_set'
	local model="$1"	# 'list' or <modelname>
	local option="$2"	# 'plain', 'js', 'info' or <empty>
	local quiet="$3"	# e.g. 'quiet' (not logging)
	local line

	[ -n "$quiet" ] && funcname="quiet_$funcname"

	# must match ' v[0-9]' and will be e.g. ' v7' -> '7' and defaults to '1'
	local version="$( echo "$model" | sed -n 's/^.* v\([0-9]\)$/\1/p' )"
	[ -z "$version" ] && version='1'

	case "$model" in
		'UML')
			# TODO: rename 'vmlinux' to e.g. 'openwrt-uml-r12345' (more readable tasklist)
			# TODO: rename 'ext4-img' to rootfs?
			TARGET_SYMBOL='CONFIG_TARGET_uml_Default=y'
			FILENAME_SYSUPGRADE='openwrt-uml-vmlinux'
			FILENAME_FACTORY='openwrt-uml-ext4.img'
			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_ROOTFS_PARTSIZE=16"	# [megabytes]

			[ "$option" = 'info' ] && {
				cat <<EOF
# simple boot via:
bin/uml/$FILENAME_SYSUPGRADE ubd0=bin/uml/$FILENAME_FACTORY eth8=tuntap,,,192.168.0.254

# when starts fails, circumvent PROT_EXEC mmap/noexec-shm-problem with:
# http://www.ime.usp.br/~baroni/docs/uml-en.html
mkdir -p /tmp/uml
chown $USER.$USER /tmp/uml
chmod 777 /tmp/uml
export TMPDIR=/tmp/uml
EOF
				return 0
			}	# parser_ignore
		;;
		'Soekris net5501')
			TARGET_SYMBOL='CONFIG_TARGET_x86_net5501=y'
			FILENAME_SYSUPGRADE='openwrt-x86-net5501-combined-ext4.img.gz'
			FILENAME_FACTORY="$FILENAME_SYSUPGRADE"
			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_PACKAGE_kmod-via-rhine=y"
		;;
		'PC Engines WRAP')
			# TODO: apply kernel-symbols: CONFIG_X86_REBOOTFIXUPS=y + CONFIG_MGEODEGX1=y
			# tinybios: enter by pressing 's' during mem-counter
			# http://wiki.openwrt.org/toh/pcengines/wrap
			TARGET_SYMBOL='CONFIG_TARGET_x86_generic_Wrap=y'
			# gunzip file.gz && dd if=file of=/dev/sdX bs=1M bs=16k && boot it!
			FILENAME_SYSUPGRADE='openwrt-x86-generic-combined-ext4.img.gz'
			# tftp only via LAN1: layout: |power LAN1 LAN2 serial|
			# dnsmasq -i eth0 --dhcp-range=192.168.1.100,192.168.1.200 \
			# --dhcp-boot=bzImage --enable-tftp --tftp-root=/tmp -u root -p0 -K --log-dhcp --bootp-dynamic
			FILENAME_FACTORY='openwrt-x86-generic-ramfs.bzImage'
			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_ROOTFS_INITRAMFS=y CONFIG_PACKAGE_hostapd-mini=y"
		;;
		'PC Engines ALIX.2')
			# tinybios: enter by pressing 's' during mem-counter
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
			# http://wiki.openwrt.org/toh/tp-link/tl-wr941nd	// todo: can be v2, v3, v4, v6
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR941=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr941nd-v4-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr941nd-v4-squashfs-factory.bin'
		;;
		'TP-LINK TL-WR1043ND'|'TP-LINK TL-WR1043ND v2')
			# http://wiki.openwrt.org/toh/tp-link/tl-wr1043nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR1043=y'
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-tl-wr1043nd-v${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-tl-wr1043nd-v${version}-squashfs-factory.bin"
		;;
		'TP-LINK TL-WDR7500'|'TP-LINK Archer C7'|'TP-LINK Archer C7 v2')
			# http://wiki.openwrt.org/toh/tp-link/tl-wdr7500
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_ARCHERC7=y'
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-archer-c7-v${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-archer-c7-v${version}-squashfs-factory.bin"
		;;
		'Mercury MAC1200R')
			# http://wiki.openwrt.org/toh/mercury/mac1200r
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_MAC1200R=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-mc-mac1200r-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-mc-mac1200r-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation2'|'Ubiquiti Picostation2'|'Ubiquiti Bullet2')
			# Atheros MIPS 4Kc @ 180 MHz / ath5k / 32 mb RAM / 8 mb FLASH
			# the other one is: Picostation M2 (HP) = MIPS 24KC / 400 MHz
			TARGET_SYMBOL='CONFIG_TARGET_atheros_Default=y'
			FILENAME_SYSUPGRADE='openwrt-atheros-combined.squashfs.img'
			FILENAME_FACTORY='openwrt-atheros-ubnt2-pico2-squashfs.bin'
		;;
		'Ubiquiti Nanostation5'|'Ubiquiti Picostation5'|'Ubiquiti WispStation5'|'Ubiquiti Bullet5')
			# Atheros MIPS 4Kc / ath5k / 32 mb RAM / 8 mb FLASH (Wispstation5 = 16/4)
			TARGET_SYMBOL='CONFIG_TARGET_atheros_Default=y'
			FILENAME_SYSUPGRADE='openwrt-atheros-combined.squashfs.img'
			FILENAME_FACTORY='openwrt-atheros-ubnt5-squashfs.bin'
		;;
		'Ubiquiti Bullet M2'|'Ubiquiti Bullet M5'|'Ubiquiti Picostation M2'|'Ubiquiti Picostation M5')
			# http://wiki.openwrt.org/toh/ubiquiti/bullet
			# http://wiki.openwrt.org/toh/ubiquiti/picostationm2
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_UBNT=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation M2'|'Ubiquiti Nanostation M5')
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
			TARGET_SYMBOL='CONFIG_TARGET_brcm47xx_legacy_Broadcom-b43=y'
			# image was 'openwrt-brcm47xx-squashfs.trx' in revision before r41530
			FILENAME_SYSUPGRADE='openwrt-brcm47xx-legacy-squashfs.trx'
			FILENAME_FACTORY='openwrt-wrt54g-squashfs.bin'

			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_brcm47xx_legacy=y CONFIG_LOW_MEMORY_FOOTPRINT=y"
		;;
		'Buffalo WHR-HP-G54'|'Dell TrueMobile 2300'|'ASUS WL-500g Premium'|'ASUS WL-500g Premium v2')
			# hint: the 'ASUS WL-500g Premium v2' needs the 'low power phy' compiled into b43
			TARGET_SYMBOL='CONFIG_TARGET_brcm47xx_Broadcom-b44-b43=y'

			if [ $( openwrt_revision_number_get ) -gt 41530 ]; then
				FILENAME_SYSUPGRADE='openwrt-brcm47xx-generic-squashfs.trx'
				FILENAME_FACTORY='openwrt-brcm47xx-generic-squashfs.trx'
			else
				FILENAME_SYSUPGRADE='openwrt-brcm47xx-squashfs.trx'
				FILENAME_FACTORY='openwrt-brcm47xx-squashfs.trx'
			fi
		;;
		'T-Mobile InternetBox TMD SB1-S'|'4G Systems MTX-1 Board')
			# http://wiki.openwrt.org/inbox/t-mobile-internetbox
			# http://wiki.openwrt.org/toh/4g.systems/access.cube
			#
			# http://www.linux-mips.org/wiki/YAMON		// 0.2.17 seems used
			# http://www.lara.prd.fr/imara/platforms/hardware/communications/4gcube/hack
			# http://fylvestre.inria.fr/pub/nylon-meshcubes/meshcube.org/meshwiki/YamonNetConsole.shtml
			# http://mirror2.openwrt.org/sources/yamonnetcon.tar.gz
			# http://wiki.freifunk-hannover.de/mediawiki/wiki/wiki/index.php?title=Meshcube
			# http://download.berlin.freifunk.net/sven-ola/nylon/readme.txt
			# http://webcache.googleusercontent.com/search?q=cache:PHP_RlZ-_qMJ:comments.gmane.org/gmane.org.freifunk.berlin/214+&cd=1&hl=de&ct=clnk&gl=de&lr=lang_de%7Clang_en
			TARGET_SYMBOL='CONFIG_TARGET_au1000_au1500=y'
			FILENAME_SYSUPGRADE='openwrt-au1000-au1500-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-au1000-au1500-vmlinux-flash.srec'
			# 'openwrt-au1000-au1500-squashfs.srec'
		;;
		'La Fonera 2.0N')
			# http://wiki.openwrt.org/toh/fon/fonera2.0n
			# SoC Type: Ralink RT3052 id:1 rev:3
			TARGET_SYMBOL='CONFIG_TARGET_ramips_rt305x_FONERA20N=y'
			FILENAME_SYSUPGRADE='openwrt-ramips-rt305x-fonera20n-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ramips-rt305x-fonera20n-squashfs-factory.bin'
		;;
		'D-Link DIR-300-B1')
			# http://wiki.openwrt.org/toh/d-link/dir-300revb
			TARGET_SYMBOL='CONFIG_TARGET_ramips_rt305x_Default=y'
			FILENAME_SYSUPGRADE='openwrt-ramips-rt305x-dir-300-b1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ramips-rt305x-dir-300-b1-squashfs-factory.bin'
		;;
		'Mikrotik Routerboard 532')
			# http://wiki.openwrt.org/toh/mikrotik/rb532
			# PCI: 168C:001B Qualcomm Atheros AR5413/AR5414 Wireless Network Adapter [AR5006X(S) 802.11abg] = R52
			# http://www.dd-wrt.com/wiki/index.php/Mikrotik_Routerboard_RB/532
			### 1 x IDT Korina 10/100 Mbit/s Fast Ethernet port  supporting Auto-MDI/X
			### 2 x VIA VT6105 10/100 Mbit/s Fast Ethernet ports supporting Auto-MDI/X
			TARGET_SYMBOL='CONFIG_TARGET_rb532_Default=y'
			FILENAME_SYSUPGRADE='openwrt-rb532-combined-jffs2-128k.bin'
			FILENAME_FACTORY='openwrt-rb532-combined-jffs2-128k.bin'	# via 'dd' to CF-card

			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_ROOTFS_JFFS2=y"
		;;
		'Seagate GoFlex Home'|'Seagate GoFlex Net')
			# http://wiki.openwrt.org/toh/seagate/goflexnet
			# http://archlinuxarm.org/platforms/armv5/seagate-goflex-home
			# http://judepereira.com/blog/hacking-your-goflex-home-2-uart-serial-console/
			# https://dev.openwrt.org/ticket/14938#comment:5

			TARGET_SYMBOL='CONFIG_TARGET_kirkwood_GOFLEXNET=y'
			FILENAME_SYSUPGRADE='openwrt-kirkwood-goflexnet-jffs2-nand-2048-128k.img'	# = rootfs
			FILENAME_FACTORY='openwrt-kirkwood-goflexnet-jffs2-nand-2048-128k.img'
			# kernel: bin/kirkwood/openwrt-kirkwood-goflexnet-uImage
			#
			# CONFIG_PACKAGE_uboot-kirkwood-goflexhome=y
			# uboot:  bin/kirkwood/uboot-kirkwood-goflexhome/openwrt-kirkwood-goflexhome-u-boot.kwb
		;;
		'Pandaboard')	# tested with: PandaBoard ES Rev B3
			TARGET_SYMBOL='CONFIG_TARGET_omap_Default=y'
			FILENAME_SYSUPGRADE='bla'
			FILENAME_FACTORY='bla'
			# openwrt-omap-Default-rootfs.tar.gz
			# openwrt-omap-zImage
			# bin/omap/dtbs/omap4-panda-es.dtb
			# uboot-omap-omap4_panda/MLO
			# uboot-omap-omap4_panda/u-boot.img

			SPECIAL_OPTIONS="$SPECIAL_OPTIONS uboot..."
		;;
		'Beagleboard')
		;;
		'FritzBox 7170')
			TARGET_SYMBOL='CONFIG_TARGET_ar7_Default=y'
			FILENAME_SYSUPGRADE='bla'
			FILENAME_FACTORY='bla'
		;;
		'list')
			case "$option" in
				'plain'|'js')
					FIRSTRUN=
				;;
				*)
					log "supported models:"
				;;
			esac

			parse_case_patterns "$funcname" | while read line; do {
				case "$option" in
					'plain')
						echo "$line"
					;;
					'js')
						# e.g. for 'typeahead.js'
						if [ -z "$FIRSTRUN" ]; then
							FIRSTRUN='false'
							echo -n "var models = ['$line'"
						else
							echo -n ", '$line'"
						fi
					;;
					*)
						echo "--hardware '$line'"
					;;
				esac
			} done

			case "$option" in
				'js')
					echo
					echo '];'
				;;
			esac

			return 0
		;;
		*)
			log "model '$model' not supported"
			return 1
		;;
	esac

	[ "$option" = 'info' ] && {
		log "no additional info for '$model' available"
		return 1
	}

	# e.g. 'CONFIG_TARGET_brcm47xx_Broadcom-b44-b43=y' -> 'brcm47xx'
	ARCH="$( echo "$TARGET_SYMBOL" | cut -d'_' -f3 )"

	# 'Linksys WRT54G/GS/GL' -> 'Linksys WRT54G:GS:GL'
	HARDWARE_MODEL_FILENAME="$( echo "$HARDWARE_MODEL" | sed 's|/|:|g' )"

	VERSION_KERNEL="$( grep ^'LINUX_VERSION:=' "target/linux/$ARCH/Makefile" | cut -d'=' -f2 )"
	[ -n "$VERSION_KERNEL" -a -n "$VERSION_KERNEL_FORCE" ] && {
		log "enforce kernel version '$VERSION_KERNEL_FORCE', was '$VERSION_KERNEL'"
		VERSION_KERNEL="$VERSION_KERNEL_FORCE"
		sed -i "s/^LINUX_VERSION:=.*/LINUX_VERSION:=${VERSION_KERNEL_FORCE}/" "target/linux/$ARCH/Makefile"
	}

	[ -z "$VERSION_KERNEL" ] && {
		# since r43047
		# KERNEL_PATCHVER:=3.10
		VERSION_KERNEL="$( grep ^'KERNEL_PATCHVER:=' "target/linux/$ARCH/Makefile" | cut -d'=' -f2 )"
		# and in 'include/kernel-version.mk'
		# LINUX_VERSION-3.10 = .58
		VERSION_KERNEL="$( grep ^"LINUX_VERSION-$VERSION_KERNEL = " 'include/kernel-version.mk' )"
		VERSION_KERNEL="$( echo "$VERSION_KERNEL" | sed 's/ = //' | sed 's/LINUX_VERSION-//' )"

		[ -n "$VERSION_KERNEL" -a -n "$VERSION_KERNEL_FORCE" ] && {
			log "enforce kernel version '$VERSION_KERNEL_FORCE', was '$VERSION_KERNEL' for r43047+"
			VERSION_KERNEL="$VERSION_KERNEL_FORCE"
			# replace in 'include/kernel-version.mk'
			# LINUX_VERSION-3.10 = .49
			# with e.g.
			# LINUX_VERSION-3.10 = .58
			# and
			# target/linux/$ARCH/Makefile
			#   -> KERNEL_PATCHVER:=3.14
			#   -> KERNEL_PATCHVER:=3.18
			sed -i "s/^KERNEL_PATCHVER:=.*/KERNEL_PATCHVER:=${VERSION_KERNEL_FORCE}/" "target/linux/$ARCH/Makefile"
		}
	}

	log "architecture: '$ARCH' model: '$model' kernel: '$VERSION_KERNEL'"

	apply_symbol 'nuke_config'
	apply_symbol "CONFIG_TARGET_${ARCH}=y"
	apply_symbol "$TARGET_SYMBOL"

	build defconfig
}

check_working_directory()
{
	local funcname='check_working_directory'
	local pattern='git-svn-id'
	local file_feeds='feeds.conf.default'
	local i=0
	local do_symlinking='no'
	local package list error repo git_url

	if [ -n "$FORCE" ]; then
		error=0
	else
		error=1
	fi

	[ -e 'build.sh' ] && {
		is_installed()
		{
			local package="$1"

			# e.g. on fedora
			which yum >/dev/null && return 0
			# yum list installed 'package_name'

			dpkg --list | grep -q "$package " && return 0
			dpkg --list | grep -q "$package:"	# e.g. zlib1g-dev:amd64
		}

		# fedora: build-essential = 'make automake gcc gcc-c++ kernel-devel'
		list='build-essential libncurses5-dev m4 flex git git-core zlib1g-dev unzip subversion gawk python libssl-dev'
		for package in $list; do {
			log "testing for '$package'" debug

			if is_installed "$package"; then
				# bastian@gcc20:~$ dpkg --status zlib1g-dev
				# dpkg-query: error: --status needs a valid package name but 'zlib1g-dev' is not:
				# ambiguous package name 'zlib1g-dev' with more than one installed instance
				#
				# bastian@gcc20:~$ dpkg -l | grep zlib1g-dev
				# ii  zlib1g-dev:amd64   1:1.2.7.dfsg-13    amd64    compression library - development
				# ii  zlib1g-dev:i386    1:1.2.7.dfsg-13    i386     compression library - development
				log "found package '$package' - OK" debug
			else
				log "missing package '$package'"
				log "please run: apt-get install --yes --force-yes '$package'"
				return $error
			fi
		} done

		[ -d 'openwrt' ] && {
			log "first start - removing (old?) dir openwrt"
			rm -fR 'openwrt'
		}

		case "$VERSION_OPENWRT" in
			'trunk')
				git_url='git://git.openwrt.org/openwrt.git'
			;;
			*'.'*)
				# e.g. 14.07
				git_url="git://git.openwrt.org/$VERSION_OPENWRT/openwrt.git"
			;;
		esac

		log "first start - fetching OpenWrt: git clone '$git_url'"
		git clone "$git_url" || return $error

		[ -d 'openwrt_download' ] && {
			log "symlinking our central download pool"
			ln -s ../openwrt_download 'openwrt/dl'
		}

		[ -d 'packages' ] && {
			log "first start - removing (old?) dir packages"
			rm -fR 'packages'
		}

		git clone 'git://nbd.name/packages.git' || return $error
		cd openwrt

# FIXME (use global var?)
#		repo='git://github.com/weimarnetz/weimarnetz.git'
		repo='git://github.com/bittorf/kalua.git'
		git clone "$repo" || return $error
		KALUA_DIRNAME="$( basename $repo | cut -d'.' -f1 )"

		log "[OK] after doing 'cd openwrt' you should do:"
		log "$KALUA_DIRNAME/openwrt-build/build.sh --help"

		exit $error
	}

	# user directory for private/overlay-files
	mkdir -p 'files'

	fgrep -q ' oonfapi ' "$file_feeds" || {
		echo >>"$file_feeds" 'src-git oonfapi http://olsr.org/git/oonf_api.git'
		log "addfeed 'oonfapi'" debug,gitadd "$file_feeds"
		do_symlinking='true'
	}

	fgrep -q ' olsrd2 '  "$file_feeds" || {
		echo >>"$file_feeds" 'src-git olsrd2  http://olsr.org/git/olsrd2.git'
		log "addfeed 'olsrd2'" debug,gitadd "$file_feeds"
		do_symlinking='true'
	}

	fgrep ' oldpackages ' "$file_feeds" | grep -q ^'#' && {
		sed -i '/oldpackages/s/^#\(.*\)/\1/' "$file_feeds"
		log "enable feed 'oldpackages'" debug,gitadd "$file_feeds"

		# https://forum.openwrt.org/viewtopic.php?id=52219
		./scripts/feeds update oldpackages  && ./scripts/feeds install -a -p oldpackages
	}

	[ -d 'package/feeds' ] || {
		# seems, everything is really untouched
		log "missing 'package/symlinks', getting feeds"
		make defconfig
		do_symlinking='true'
	}

	[ "$do_symlinking" = 'true' ] && {
		log "enforce/updating symlinking of packages"
		make package/symlinks
	}

	git log -1 | grep -q "$pattern" || {
		if git log | grep -q "$pattern"; then
			log "the last commit MUST include '$pattern', seems you have private"
			log "commits - please rollback several times via: git reset --soft HEAD^"

			while ! git log -$i | grep -q "$pattern"; do {
				i=$(( $i + 1 ))
			} done

			log "or just do: git reset --soft HEAD~$i"
			log "you can switch back via: git reflog; git reset \$hash"
		else
			log "please make sure, that you are in OpenWrt's git-root"
		fi

		return $error
	}

	ls -d "$KALUA_DIRNAME" >/dev/null || {
		log "please make sure, that directory '$KALUA_DIRNAME' exists"
		return $error
	}
}

openwrt_revision_number_get()		# e.g. 43234
{
	local rev="$( git log -1 | grep 'git-svn-id' | cut -d'@' -f2 | cut -d' ' -f1 )"

	if [ -n "$rev" ]; then
		echo "$rev"
	else
		# is not available in all revisions or during early bootstrapping
		[ -e 'scripts/getver.sh' ] && scripts/getver.sh | cut -d'r' -f2
	fi
}

openwrt_download()
{
	local funcname='openwrt_download'
	local wish="$1"		# <empty> = 'leave_untouched'
				# or 'r12345' or
				# or 'stable' or 'beta' or 'testing'
				# or 'trunk'
	local hash branch
	local old_wish="$wish"

	log "apply '$wish'"

	case "$wish" in
		'')
			wish='leave_untouched'
		;;
		'stable')
			wish='r44150'
		;;
		'beta')
			wish='r45039'
		;;
		'testing')
			# maybe this is too simply, because it applies to all platforms?
			wish='r45514'
		;;
	esac

	[ "$old_wish" = "$wish" ] || log "apply '$wish' (sanitized)"

	case "$wish" in
		'leave_untouched')
			# e.g.: r12345
			VERSION_OPENWRT="r$( openwrt_revision_number_get )"
		;;
		'trunk')
			$funcname 'switch_to_master'

			git pull
			scripts/feeds update

			log "checkout local copy of trunk/$VERSION_OPENWRT"
			$funcname "$VERSION_OPENWRT"
		;;
		'r'*)
			$funcname 'switch_to_master'

			# typical entry:
			# git-svn-id: svn://svn.openwrt.org/openwrt/trunk@39864 3c298f89-4303-0410-b956-a3cf2f4a3e73
			hash="$( echo "$wish" | cut -b2- )"			# r12345 -> 12345  (remove leading 'r')
			hash="$( git log --format=%h --grep="@$hash " )"	# 12345 -> fe53cab (number -> hash)

			[ -z "$hash" ] && {
				log "[ERROR] - unable to find $wish"
				# can happen if 'rXXXXX' is in packages/feeds, just use newest:
				hash="$( git log -1 --format=%h )"
			}

			git branch | grep -q ^"  openwrt@${hash}=${wish}"$ && {
				log "removing old? branch 'openwrt@${hash}=${wish}'"
				git branch -D "openwrt@${hash}=${wish}" || {
					log "removing failed, will 'stash' and try again"
					git stash
					git branch -D "openwrt@${hash}=${wish}"
				}
			}

			git checkout -b "openwrt@${hash}=${wish}" "$hash" || {
				log "checkout failed, trying to stash"
				git stash save "going to checkout ${hash}=${wish}"

				git checkout -b "openwrt@${hash}=${wish}" "$hash" || {
					log "checkout still failing, abort - see stash:" || {
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
				if git checkout master >/dev/null; then
					git branch -D "$branch" || log "[ERR] failed deleting branch '$branch'"
				else
					log "[ERROR] cannot switch to master, stashing"
					git stash list

					git stash save "going to checkout master"

					if git checkout master >/dev/null; then
						log "leaving branch '$branch'"
					else
						log "[ERROR] cannot switch to master"
						return 1
					fi
				fi
			else
				log "already at branch 'master" debug
			fi

			# e.g.: r12345 - command 'scripts/getver.sh' is not available in all revisions
			VERSION_OPENWRT="r$( git log -1 | grep 'git-svn-id' | cut -d'@' -f2 | cut -d' ' -f1 )"

			[ -n "$( git stash list | grep -v '() going to checkout ' )" ] && {
				log "found openwrt-stash, ignore via press 'q'"
				log "or use e.g. 'git stash list' OR 'git pop' OR 'git apply stash@{0}' OR 'git stash clear'"

				git stash list
			}
		;;
		*)
			log "unknown option '$wish'"

			return 1
		;;
	esac

	return 0
}

usecase_hash()		# see: _firmware_get_usecase()
{
	local usecase="$1"
	local oldIFS="$IFS"; IFS=','; set -- $usecase; IFS="$oldIFS"

	# print each word without appended version @...
	# output the same hash, no matter in which order the words are
	while [ -n "$1" ]; do {
		echo "${1%@*}"
		shift
	} done | sort | md5sum | cut -d' ' -f1
}

copy_firmware_files()
{
	local funcname='copy_firmware_files'
	local attic="bin/$ARCH/attic"
	local file checksum rootfs server_dir
	local destination destination_scpsafe destination_info destination_info_scpsafa
	local error=0

	mkdir -p "$attic"
	rootfs='squash'

	log "openwrt-version: '$VERSION_OPENWRT' with kernel: '$VERSION_KERNEL' for arch '$ARCH'"
	log "hardware: '$HARDWARE_MODEL'"
	log "usecase: --usecase $LIST_OPTIONS"
	log "usecase-hash: $( usecase_hash "$LIST_OPTIONS" )"

	# http://intercity-vpn.de/firmware/mpc85xx/images/testing/1c78c7a701714cddd092279587e719a3/TP-LINK%20TL-WDR4900%20v1.bin
	log "http://intercity-vpn.de/firmware/$ARCH/images/testing/usecase/$( usecase_hash "$LIST_OPTIONS" )/$HARDWARE_MODEL.bin"
	log "http://intercity-vpn.de/firmware/$HARDWARE_MODEL/testing/usecase/..."
	log "http://intercity-vpn.de/networks/xyz/firmware/$HARDWARE_MODEL/testing/usecase/..."

	# Ubiquiti Bullet M
	destination="$HARDWARE_MODEL_FILENAME"

	# Ubiquiti Bullet M.openwrt=r38576
	destination="${destination}.openwrt=${VERSION_OPENWRT}"

	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11
	destination="${destination}_kernel=${VERSION_KERNEL}"

	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_rootfs=squash
	destination="${destination}_rootfs=$rootfs"

	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_rootfs=squash_image=sysupgrade
	if [ -n "$CONFIG_PROFILE" ]; then
		destination="${destination}_image=factory"
	else
		destination="${destination}_image=sysupgrade"
	fi
	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_rootfs=squash_image=sysupgrade_option=Standard,kalua@5dce00c
	destination="${destination}_option=${LIST_OPTIONS}"

	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_rootfs=squash_image=sysupgrade_option=Standard,kalua@5dce00c_profile=liszt28.hybrid.4
	[ -n "$CONFIG_PROFILE" ] && {
		log "enforced_profile: $CONFIG_PROFILE"
		destination="${destination}_profile=${CONFIG_PROFILE}"
	}

	# Ubiquiti Bullet M.openwrt=r41000_kernel=3.10.5_rootfs=squash_image=sysupgrade_option=Small,OLSRd,kalua@5dce00c.bin
	# Ubiquiti Bullet M.openwrt=r41000_kernel=3.10.5_rootfs=squash_image=sysupgrade_option=Standard,kalua@5dce00c.bin
	# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_rootfs=squash_image=sysupgrade_option=Standard,kalua@5dce00c.bin
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

	if [ -e "$file" ]; then
		cp -v "$file" "$attic/$destination"
	else
		error=1
	fi

	log "$( wc -c <"bin/$ARCH/$FILENAME_SYSUPGRADE" ) Bytes: '$FILENAME_SYSUPGRADE'"
	log "$( wc -c <"bin/$ARCH/$FILENAME_FACTORY" ) Bytes: '$FILENAME_FACTORY'"

	if [ -e "bin/$ARCH/$FILENAME_FACTORY" ]; then
		:
	else
		error=1
	fi

	# scp bin/ar71xx/attic/TP-LINK\ TL-WR1043ND.openwrt\=r43238_kernel\=3.10.58_option\=Standard\,VDS\,kalua\@5415ee5_rootfs\=squash_image\=sysupgrade.bin root@intercity-vpn.de:/var/www/firmware/ar71xx/images/testing/usecase/
	# auf server:
	# cd /var/www/firmware/ar71xx/images/testing/usecase/
	# cd Standard,VDS,kalua
	# rm "TP-LINK TL-WR1043ND.bin"
	# ln -s ../TP-LINK\ TL-WR1043ND.openwrt\=r43238_kernel\=3.10.58_option\=Standard\,VDS\,kalua\@5415ee5_rootfs\=squash_image\=sysupgrade.bin "TP-LINK TL-WR1043ND.bin"

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

calc_time_diff()
{
	local t1="$1"		# e.g. read t1 rest </proc/uptime
	local t2="$2"
	local duration

	duration=$(( ${t2%.*}${t2#*.} - ${t1%.*}${t1#*.} ))
	duration=$(( duration / 100 )).$(( duration % 100 ))

	echo "$duration"
}

build()
{
	local funcname='build'
	local option="$1"
	local cpu_count="$( grep -c ^'processor' '/proc/cpuinfo' )"
	local jobs=$(( $cpu_count + 1 ))
	local commandline="--jobs $jobs BUILD_LOG=1"
	local verbose t1 t2 rest
	[ -n "$DEBUG" ] && verbose='V=s'

	case "$option" in
		'nuke_bindir')
			log "$option: removing unneeded firmware/packages, but leaving 'attic'-dir"
			rm     "bin/$ARCH/"*	    2>/dev/null
			rm -fR "bin/$ARCH/packages" 2>/dev/null
		;;
		'defconfig')
			log "running 'make defconfig'" debug

			make $verbose defconfig >/dev/null || make defconfig
		;;
		*)
			[ -n "$MAC80211_CLEAN" ] && {
				log "running 'make package/kernel/mac80211/clean'"
				make package/kernel/mac80211/clean
			}

			log "running 'make $commandline'"
			read t1 rest </proc/uptime

			if make $verbose $commandline ; then
				read t2 rest </proc/uptime
				BUILD_DURATION="$( calc_time_diff "$t1" "$t2" )"
				log "running 'make $commandline' lasts $BUILD_DURATION sec"

				if [ "$FAIL" = 'true' ]; then
					log "keeping state, so you can make changes and build again"
					return 1
				else
					return 0
				fi
			else
				log "[ERROR] during make: check directory logs/ with"
				log "find logs -type f -exec stat -c '%y %N' {} \; | sort -n"
				log "first build unparallel with 'make -j1 BUILD_LOG=1'"
				return 1
			fi
		;;
	esac
}

apply_symbol()
{
	local funcname='apply_symbol'
	local symbol="$1"
	local file='.config'
	local custom_dir='files'	# standard way to add/customize
	local choice hash tarball_hash rev
	local last_commit_unixtime last_commit_date url
	local file installation sub_profile node
	local dir basedir pre size1 size2 gain

	case "$symbol" in
		"$KALUA_DIRNAME"*)
			log "$KALUA_DIRNAME: getting files"

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

			# r40296 = [mac80211]: skip antenna gain when compiling regdb.txt
			# r40293 = [mac80211]: update regulatory database to 2013-11-27
#			for rev in 40296 40293; do {
#				hash="$( git log --format=%h --grep="@$rev " )"
#				[ -n "$hash" ] && {
#					log "git-revert r$rev / $hash"
#					git revert $hash
#				}
#			} done

			log "$KALUA_DIRNAME: adding ${KALUA_DIRNAME}-files @$VERSION_KALUA to custom-dir '$custom_dir/'"
			cp -R $KALUA_DIRNAME/openwrt-addons/* "$custom_dir"

			log "$KALUA_DIRNAME: adding 'apply_profile' stuff to '$custom_dir/etc/init.d/'"
			cp "$KALUA_DIRNAME/openwrt-build/apply_profile"* "$custom_dir/etc/init.d"

			log "$KALUA_DIRNAME: adding initial rc.local"
			echo  >'package/base-files/files/etc/rc.local' '#!/bin/sh'
			echo >>'package/base-files/files/etc/rc.local' "[ -e '/tmp/loader' ] || /etc/init.d/cron.user boot"
			echo >>'package/base-files/files/etc/rc.local' 'exit 0'
			log "own rc.local" gitadd "package/base-files/files/etc/rc.local"

			log "$KALUA_DIRNAME: adding version-information = '$last_commit_date'"
			echo  >"$custom_dir/etc/variables_fff+" "FFF_PLUS_VERSION=$last_commit_unixtime_in_hours	# $last_commit_date"
			echo >>"$custom_dir/etc/variables_fff+" "FFF_VERSION=2.0.0			# OpenWrt based / unused"

			log "$KALUA_DIRNAME: adding hardware-model to 'files/etc/HARDWARE'"
			echo >"$custom_dir/etc/HARDWARE" "$HARDWARE_MODEL"

			log "[OK] added custom dir" gitadd "$custom_dir"

			log "$KALUA_DIRNAME: tweaking kernel commandline"
			kernel_commandline_tweak

			case "$LIST_USER_OPTIONS" in
				*'noReghack'*)
					log "$KALUA_DIRNAME: disable Reghack"
					apply_wifi_reghack 'disable'
				;;
				*)
					log "$KALUA_DIRNAME: apply_wifi_reghack"
					apply_wifi_reghack
				;;
			esac

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
#			log "$KALUA_DIRNAME: compiler tweaks"
#			apply_symbol 'CONFIG_DEVEL=y'		# 'Advanced configuration options'
#			apply_symbol 'CONFIG_EXTRA_OPTIMIZATION="-fno-caller-saves -fstack-protector -fstack-protector-all -fno-delete-null-pointer-checks"'

			url="http://intercity-vpn.de/firmware/$ARCH/images/testing/info.txt"
			log "$KALUA_DIRNAME: adding recent tarball hash from '$url'"
			tarball_hash="$( wget -qO - "$url" | fgrep 'tarball.tgz' | cut -d' ' -f2 )"
			if [ -z "$tarball_hash" ]; then
				log "[ERR] cannot fetch tarball hash from '$url', be prepared that node will automatically update upon first boot"
			else
				echo >'files/etc/tarball_last_applied_hash' "$tarball_hash"
			fi

			if [ -e '/tmp/apply_profile.code.definitions' ]; then
				log "$KALUA_DIRNAME: using custom '/tmp/apply_profile.code.definitions'"
				cp '/tmp/apply_profile.code.definitions' "$custom_dir/etc/init.d/apply_profile.code.definitions.private"
			else
				[ -e "$custom_dir/etc/init.d/apply_profile.code.definitions.private" ] && rm "$custom_dir/etc/init.d/apply_profile.code.definitions.private"
				log "$KALUA_DIRNAME: no '/tmp/apply_profile.code.definitions' found, using standard $KALUA_DIRNAME file"
			fi

			for basedir in "$KALUA_DIRNAME/openwrt-patches/add2trunk" $PATCHDIR; do {
				find $basedir | while read file; do {
					if [ -d "$file" ]; then
						log "dir: $file"
						register_patch "DIR: $file"
					else
						if   head -n1 "$file" | fgrep -q '/net/mac80211/'; then
							register_patch "$file"
							cp -v "$file" 'package/kernel/mac80211/patches'
							MAC80211_CLEAN='true'
						elif head -n1 "$file" | fgrep -q '/drivers/net/wireless/ath/'; then
							register_patch "$file"
							cp -v "$file" 'package/kernel/mac80211/patches'
							MAC80211_CLEAN='true'
						else
							if git apply --check <"$file"; then
								# http://stackoverflow.com/questions/15934101/applying-a-diff-file-with-git
								# http://stackoverflow.com/questions/3921409/how-to-know-if-there-is-a-git-rebase-in-progress
								[ -d '.git/rebase-merge' -o -d '.git/rebase-apply' ] && {
									git rebase --abort
									git am --abort
								}

								if git am --signoff <"$file"; then
									register_patch "$file"
								else
									git am --abort
									log "[ERROR] during 'git am <$file'"
								fi
							else
								register_patch "FAILED: $file"
								log "$KALUA_DIRNAME: [ERROR] cannot apply: git apply --check <'$file'"
							fi
						fi
					fi
				} done
			} done

			[ -n "$CONFIG_PROFILE" ] && {
				file="$custom_dir/etc/init.d/apply_profile.code"
				installation="$( echo "$CONFIG_PROFILE" | cut -d'.' -f1 )"
				sub_profile="$(  echo "$CONFIG_PROFILE" | cut -d'.' -f2 )"
				node="$(         echo "$CONFIG_PROFILE" | cut -d'.' -f3 )"

				log "$KALUA_DIRNAME: enforced profile: $installation - $sub_profile - $node"
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

			set -- $( du -s "$custom_dir" )
			size1="$1"
			tar czf "$custom_dir.tgz" "$custom_dir"
			set -- $( du -s "$custom_dir.tgz" && rm "$custom_dir.tgz" )
			size2="$1"
			gain=$(( $size2 * 100 / $size1 ))
			log "[OK] custom dir '$custom_dir' adds $size1 kilobytes (~${size2}k = ${gain}% compressed) to your image"

			return 0
		;;
		'nuke_customdir')
			log "emptying dir for custom files: '$custom_dir/'"
			rm -fR "$custom_dir"
			mkdir  "$custom_dir"

			return 0
		;;
		'kernel')
			# apply_symbol kernel 'CONFIG_PRINTK is not set' -> 'CONFIG_KERNEL_PRINTK is not set'
			log "working on kernel-symbol $2"
			apply_symbol "$( echo "$2" | sed 's/CONFIG_/CONFIG_KERNEL_/' )"
			return 0
		;;
		'nuke_config')
			register_patch 'init'

			log "$symbol: starting with an empty config"
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
			log "symbol: $symbol" debug
		;;
		*)
			log "symbol: $symbol"
		;;
	esac

	case "$symbol" in
		'CONFIG_BUSYBOX'*)
			# maybe unneeded
			grep -q 'CONFIG_BUSYBOX_CUSTOM=y' "$file" || {
				log "enabling BUSYBOX_CUSTOM"
				echo 'CONFIG_BUSYBOX_CUSTOM=y' >>"$file"
			}
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
	local kmod

	# shift args, because the call is: $funcname 'subcall' "$opt"
	[ "$options" = 'subcall' -a -n "$subcall" ] && options="$subcall"

	set -- $( serialize_comma_list "$options" )
	while [ -n "$1" ]; do {
		if [ "$1" = 'list' ]; then
			log "apply '$1' ${subcall:+(subcall)}" debug
		else
			log "apply '$1' ${subcall:+(subcall)}"
		fi

		# build a comma-separated list for later output/build-documentation
		case "${subcall}-$1" in
			"-$KALUA_DIRNAME"*)
				# parser_ignore
				# direct call to kalua (no subcall)
			;;
			*'=y'|*[.0-9])
				# parser_ignore
				# e.g. CONFIG_TARGET_ROOTFS_INITRAMFS=y
				# e.g. SQUASHFS_BLOCK_SIZE=64
			;;
			'-'*)	# parser_process
				# direct call (no subcall)
				LIST_OPTIONS="${LIST_OPTIONS}${LIST_OPTIONS+,}${1}"
			;;
		esac

		case "$1" in
			'CONFIG_'*)
				apply_symbol "$1"
			;;
			'defconfig')
				# this simply adds or deletes no symbols
			;;
			"$KALUA_DIRNAME")
				apply_symbol "$1"
			;;
			"$KALUA_DIRNAME@"*)	# parser_ignore
				apply_symbol "$1"
			;;
			'noReghack')
				# we work on this during above $KALUA_DIRNAME
			;;
			'MinstrelRhapsody')
				apply_minstrel_rhapsody
				apply_symbol 'CONFIG_PACKAGE_MAC80211_RC_RHAPSODY_BLUES=y'
			;;
			'zRAM')
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_SWAPONOFF=y'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_SWAPON_PRI=y'
				apply_symbol 'CONFIG_PACKAGE_zram-swap=y'		# base-system: zram-swap

# https://dev.openwrt.org/ticket/19586
#				apply_symbol 'CONFIG_PROCD_ZRAM_TMPFS=y'		# since r43489
#				apply_symbol 'CONFIG_PACKAGE_kmod-fs-ext4=y'		# needed for compressed ramdisc
#				apply_symbol 'CONFIG_PACKAGE_e2fsprogs=y'		# dito | utilities: filesystem:
			;;
			'Standard')	# >4mb flash
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_ip=y'			# network: routing/redirection: ip
				apply_symbol 'CONFIG_PACKAGE_resolveip=y'		# base-system: +3k
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g
				apply_symbol 'CONFIG_PACKAGE_mii-tool=y'		# network: mii-tool:
				apply_symbol 'CONFIG_PACKAGE_rrdtool1=y'		# utilities: rrdtool:
				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless:
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools (=iwconfig)
				apply_symbol 'CONFIG_PACKAGE_curl=y'			# network: file-transfer: curl
#				apply_symbol 'CONFIG_PACKAGE_memtester=y'		# utilities:
				apply_symbol 'CONFIG_PROCD_SHOW_BOOT=y'

				$funcname subcall 'squash64'
				$funcname subcall 'zRAM'
				$funcname subcall 'netcatFull'
				$funcname subcall 'shaping'
				$funcname subcall 'vtun'
				$funcname subcall 'mesh'
				$funcname subcall 'noFW'
			;;
			'Small')	# <4mb flash - for a working jffs2 it should not exceed '3.670.020' bytes (e.g. WR703N)
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_ip=y'			# network: routing/redirection: ip
				apply_symbol 'CONFIG_PACKAGE_resolveip=y'		# base-system: +3k
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
#				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
#				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g
				apply_symbol 'CONFIG_PACKAGE_mii-tool=y'		# network: mii-tool: (very small)
#				apply_symbol 'CONFIG_PACKAGE_rrdtool1=y'		# utilities: rrdtool:
#				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless: (but debugFS-export still active)
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
#				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools
#				apply_symbol 'CONFIG_PACKAGE_curl=y'
#				apply_symbol 'CONFIG_PACKAGE_memtester=y'
#				apply_symbol 'CONFIG_PROCD_SHOW_BOOT=y'

#				$funcname subcall 'squash64'
				$funcname subcall 'zRAM'
				$funcname subcall 'netcatFull'
#				$funcname subcall 'shaping'
#				$funcname subcall 'vtun'
#				$funcname subcall 'mesh'
				$funcname subcall 'noFW'
			;;
			'Mini')
				# be careful: getting firmware and reflash must be possible (or bootloader with TFTP needed)
				# like small and: noMESH, noSSH, noOPKG, noSwap, noUHTTPD, noIPTables
				# -coredump,-debug,-symbol-table
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# kernel-modules: wireless:

				# CONFIG_PACKAGE_dropbear is not set
				# CONFIG_PACKAGE_opkg is not set

				$funcname subcall 'noFW'
				$funcname subcall 'noIPv6'
				$funcname subcall 'noPPPoE'
			;;
			'Micro')
				# like mini and: noWiFi, noDNSmasq, noJFFS2-support?
				# remove 'mtd' if device can be flashed via bootloader?
			;;
			### here starts all functions/packages, above are 'meta'-descriptions ###
			'debug')
				apply_symbol 'CONFIG_USE_STRIP=y'			# Global build settings: Binary stripping method
				apply_symbol 'CONFIG_USE_SSTRIP is not set'
				apply_symbol 'CONFIG_STRIP_ARGS="--strip-all"'
			;;
			'netcatFull')
				# without / with
				# 353.824 / 355.095 bytes - staging_dir/target-mips_34kc_uClibc-0.9.33.2/root-ar71xx/bin/busybox
				# 203.141 / 205.202 bytes - bin/ar71xx/packages/base/busybox_1.22.1-4_ar71xx.ipk
				apply_symbol 'CONFIG_BUSYBOX_CUSTOM=y'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_NC_SERVER=y'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_NC_EXTRA=y'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_NC_110_COMPAT=y'
			;;
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
				apply_symbol 'CONFIG_PACKAGE_kmod-ifb=y'		# kernel-modules: network devices:
			;;
			'b43mini')
				apply_symbol 'CONFIG_B43_FW_SQUASH_PHYTYPES="G"'	# kernel-modules: wireless: b43
				apply_symbol 'CONFIG_PACKAGE_B43_PHY_LP is not set'
				apply_symbol 'CONFIG_PACKAGE_B43_PHY_N is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_B43_PHY_HT is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_kmod-b43legacy is not set'	# kernel-modules:
				apply_symbol 'CONFIG_PACKAGE_kmod-bgmac is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-tg3 is not set'
				# apply_symbol 'CONFIG_PACKAGE_B43_DEBUG=y'
			;;
			'WiFi'*)
				# generic approach:
				# e.g usb-wifi-stick: rtl8192cu -> WiFi-rtl8192cu
				# ID 7392:7811 Edimax Technology Co., Ltd EW-7811Un 802.11n Wireless Adapter [Realtek RTL8188CUS]
				# or
				# CONFIG_PACKAGE_kmod-ath5k=y -> WiFi-ath5k

				kmod="$( echo "$1" | cut -d'-' -f2 )"			# WiFi-rtl8192cu -> rtl8192cu
				apply_symbol "CONFIG_PACKAGE_kmod-${kmod}=y"		# kernel-modules: wireless:
			;;
			'Arduino')
				$funcname subcall 'USBserial'
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-acm=y'		# kernel-modules: USB-support
			;;
			'USBserial')
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-serial=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-serial-ftdi=y'
			;;
			'USBstorage')
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-storage=y'	# kernel-modules: USB-support
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-storage-extras=y'	# kernel-modules: USB-support
				apply_symbol 'CONFIG_PACKAGE_kmod-fs-ext4=y'		# kernel-modules: filesystems
				apply_symbol 'CONFIG_PACKAGE_kmod-fs-vfat=y'		# kernel-modules: filesystems
				apply_symbol 'CONFIG_PACKAGE_kmod-nls-cp437=y'		# kernel-modules: nls-support (USA)
				apply_symbol 'CONFIG_PACKAGE_kmod-nls-iso8859-1=y'	# kernel-modules: nls-support (EU)
			;;
			'BTRfs')
				apply_symbol 'CONFIG_PACKAGE_kmod-fs-btrfs=y'		# kernel-modules: filesystems
				apply_symbol 'CONFIG_PACKAGE_btrfs-progs=y'		# utilities: filesystem
			;;
			'NAS')
				apply_symbol 'CONFIG_PACKAGE_smartd=y'			# utilities -> smart
				apply_symbol 'CONFIG_PACKAGE_smartmontools=y'		# utilities -> smart
				apply_symbol 'CONFIG_PACKAGE_kmod-loop=y'		# kernel-modules: block-devices
			;;
			'NTPfull')
				apply_symbol 'CONFIG_PACKAGE_ntp-utils=y'		# network -> time_syncronisation
				apply_symbol 'CONFIG_PACKAGE_ntpd=y'			# network -> time_syncronisation
				apply_symbol 'CONFIG_PACKAGE_ntpdate=y'
				apply_symbol 'CONFIG_PACKAGE_ntpclient=y'
			;;
			'BigBrother')
				$funcname subcall 'USBcam'
				apply_symbol 'CONFIG_PACKAGE_ffmpeg=y'
				apply_symbol 'CONFIG_PACKAGE_motion=y'
			;;
			'BigBrotherMini')
				$funcname subcall 'BigBrother'
				apply_symbol 'CONFIG_PACKAGE_libffmpeg-mini=y'
			;;
			'Photograph')
				$funcname subcall 'USBcam'
				apply_symbol 'CONFIG_PACKAGE_fswebcam=y'		# multimedia:
			;;
			'DSLR')	# http://en.wikipedia.org/wiki/Digital_single-lens_reflex_camera
				apply_symbol 'CONFIG_PACKAGE_gphoto2=y'			# multimedia
				apply_symbol 'CONFIG_PACKAGE_libgphoto2-drivers'	# libraries
			;;
			'USBcam')
				apply_symbol 'CONFIG_PACKAGE_kmod-video-core=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-video-uvc=y'
				apply_symbol 'CONFIG_PACKAGE_v4l-utils=y'
			;;
			'USBaudio')
				apply_symbol 'CONFIG_PACKAGE_madplay=y'			# sound: madplay
				apply_symbol 'CONFIG_PACKAGE_kmod-sound-core=y'		# kernel-modules: sound:
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-audio=y'		# ...
#				apply_symbol 'CONFIG_PACKAGE_kmod-input-core=y'		# ...
			;;
			'MPDmini')
				# + 1.5mb -> 1043er = too slow
				apply_symbol 'CONFIG_PACKAGE_mpd-mini=y'		# sound: mpd-mini
			;;
#			'SPEECHsynth-espeak')
#				# + 1.5mb
#			;;
#			'SPEECHsynth-flite')
#				# + 6.3mb
#			;;
			'LuCI')
				# FIXME!
				apply_symbol 'CONFIG_PACKAGE_luci-mod-admin-core=y'	# LuCI: modules
			;;
			'LuCIfull')
				apply_symbol 'CONFIG_PACKAGE_luci=y'			# LuCI: collections
			;;
			'vtun')
				apply_symbol 'CONFIG_PACKAGE_vtun=y'			# network: vpn: vtun:
				apply_symbol 'CONFIG_VTUN_SSL is not set'		# ...
#				apply_symbol 'CONFIG_VTUN_LZO is not set'		# ...
			;;
			'mesh')
				$funcname subcall 'OLSRd'
#				$funcname subcall 'BatmanAdv'
			;;
			'OLSRd')
				apply_symbol 'CONFIG_PACKAGE_olsrd=y'			# network: routing/redirection: olsrd:
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-nameservice=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-txtinfo=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-jsoninfo=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-watchdog=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-dyn-gw-plain=y'	# ...

				$funcname subcall 'macVLAN'
			;;
			'OLSRd2')
				apply_symbol 'CONFIG_PACKAGE_olsrd2-git=y'		# network:
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH=y'
			;;
			'DCF77')
				$funcname subcall 'USBserial'
				$funcname subcall 'NTPfull'
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
			'noSSH')
				apply_symbol 'CONFIG_PACKAGE_dropbear is not set'
			;;
			'noDebug')
				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG is not set'
				apply_symbol 'CONFIG_PACKAGE_MAC80211_DEBUGFS is not set'

				apply_symbol kernel 'CONFIG_DEBUG_FS is not set'
				apply_symbol kernel 'CONFIG_KALLSYMS is not set'
				apply_symbol kernel 'CONFIG_DEBUG_KERNEL is not set'
				apply_symbol kernel 'CONFIG_DEBUG_INFO is not set'
				apply_symbol kernel 'CONFIG_ELF_CORE is not set'

				$funcname subcall 'noPrintK'
			;;
			'noIPv6')
				# seems not to work with brcm47xx, but with ar71xx?! -> see 'DEFAULT's
				$funcname subcall 'noFW'

				# after apply, we can still see:
				# CONFIG_DEFAULT_ip6tables=y
				# CONFIG_PACKAGE_libip6tc=y

				# CONFIG_PACKAGE_libip6tc=y
				# CONFIG_PACKAGE_libxtables=y
				# CONFIG_DEFAULT_6relayd=y
				# CONFIG_DEFAULT_ip6tables=y
				# CONFIG_DEFAULT_odhcp6c=y

				apply_symbol 'CONFIG_IPV6 is not set'			# global build settings: IPv6 support in packages
				apply_symbol 'CONFIG_PACKAGE_6relayd is not set'	# network: 6relayd - removed in r40893
				apply_symbol 'CONFIG_PACKAGE_odhcp6c is not set'	# network: odhcp6c
				apply_symbol 'CONFIG_PACKAGE_odhcpd is not set'		# network: odhcpd
				apply_symbol 'CONFIG_PACKAGE_kmod-ip6tables is not set'	# kernel-modules: netfilter-extensions: ip6tables
				apply_symbol 'CONFIG_PACKAGE_kmod-ipv6 is not set'	# kernel-modules: network-support: kmod-ipv6
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_IPV6 is not set'	# base/busybox/networking/ipv6-support
				apply_symbol 'CONFIG_PACKAGE_libip6tc is not set'
			;;
			'noOPKG')
				apply_symbol 'CONFIG_PACKAGE_opkg is not set'		# base-system: opkg

				log "noOPKG: writing under 'files/etc/opkg.conf'"
				mkdir -p 'files/etc'
				cat >'files/etc/opkg.conf' <<EOF
dest root /
dest ram /tmp
lists_dir ext /var/opkg-lists
option overlay_root /overlay
src/gz chaos_calmer_base http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/base
src/gz chaos_calmer_luci http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/luci
src/gz chaos_calmer_management http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/management
src/gz chaos_calmer_oldpackages http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/oldpackages
src/gz chaos_calmer_olsrd2 http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/olsrd2
src/gz chaos_calmer_oonfapi http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/oonfapi
src/gz chaos_calmer_packages http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/packages
src/gz chaos_calmer_routing http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/routing
src/gz chaos_calmer_telephony http://downloads.openwrt.org/snapshots/trunk/$ARCH/generic/packages/telephony
EOF
			;;
			'noPPPoE')
				apply_symbol 'CONFIG_PACKAGE_ppp is not set'		# network: ppp
				apply_symbol 'CONFIG_PACKAGE_kmod-ppp is not set'	# kernel-modules: network-support: ppp
				apply_symbol 'CONFIG_PACKAGE_kmod-pppoe is not set'	# needed?
				apply_symbol 'CONFIG_PACKAGE_kmod-pppox is not set'	# needed?
			;;
			'noPrintK')
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_DMESG is not set'

				apply_symbol kernel 'CONFIG_PRINTK is not set'		# general setup: standard kernel features
				apply_symbol kernel 'CONFIG_EARLY_PRINTK is not set'	# kernel hacking: early printk
				apply_symbol kernel 'CONFIG_SYS_HAS_EARLY_PRINTK is not set'
			;;
			'noWIFI')
				apply_symbol 'CONFIG_PACKAGE_kmod-cfg80211 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-mac80211 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-mac80211-hwsim is not set'
				apply_symbol 'CONFIG_PACKAGE_hostapd-common is not set'
				apply_symbol 'CONFIG_PACKAGE_iw is not set'
				apply_symbol 'CONFIG_PACKAGE_wpad-mini is not set'
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
			'squash64'|'squash256'|'squash1024')
				# smaller -> bigger image, but lowering ram-usage
				# bigger  -> smaller image, needs more ram
				apply_symbol "CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=${1#*squash}"	# target images: squashfs
				register_patch "$1"
			;;
			# help/usage-function
			'list')
				[ "$subcall" = 'plain' ] || log "supported options:"

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
				log "unknown option '$1'"

				return 1
			;;
		esac

		build 'defconfig'
		shift
	} done

	buildinfo_needs_adding()
	{
		[ -n "$subcall" ] && return 1

		case "$LIST_OPTIONS" in
			'CONFIG_'*)
				return 1
			;;
			'')
				echo	# last command doesnt set the cursor at line begin ("Collecting package info: done")
				return 1
			;;
			*)
				return 0
			;;
		esac
	}

	buildinfo_needs_adding && {
		log "adding build-information '$LIST_OPTIONS' to '$custom_dir/etc/openwrt_build'"
		mkdir -p "$custom_dir/etc"
		echo "$LIST_OPTIONS" >"$custom_dir/etc/openwrt_build"
	}

	return 0
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
							'"'*)	# e.g. "myword"
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
								# e.g. 'myword'
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

check_scripts()
{
	local dir="$1"
	local tempfile="/tmp/check_scripts"
	local file i mimetype

	find "$dir" -type f -not -iwholename '*.git*' >"$tempfile"

	while read file; do {
		set -- $( file '--mime-type' "$file" )
		mimetype="$@"
		mimetype=${mimetype##* }	# last word

		case "$mimetype" in
			'text/html')
				case "$( basename "$file" )" in
					*'.js'*)
						# support missing:
						# https://github.com/file/file/blob/master/magic/Magdir/javascript
						mimetype='application/javascript'
					;;
				esac
			;;
		esac

		case "$mimetype" in
			'text/plain')
				log "[OK] will not check '$mimetype' file '$file'" debug
			;;
			'inode/x-empty'|'application/x-empty')
				log "[OK] will not check empty file '$file'" debug
			;;
			'text/html')
				# w3c-markup-validator + https://github.com/ysangkok/w3c-validator-runner -> always fails?
				# tidy works: http://www.html-tidy.org/
				if which tidy >/dev/null; then
					log "checking $mimetype / $file"
					tidy -errors "$file" 2>/dev/null || return 1
				else
					log "[OK] will not check '$mimetype' file '$file'" debug
				fi
			;;
			'text/x-php')
				if which php >/dev/null; then
					log "checking $mimetype / $file"
					php -l "$file" || return 1
				else
					log "[OK] will not check '$mimetype' file '$file'" debug
				fi
			;;
			'text/x-c'|'text/x-c++')
				# cppcheck?
				if which cppcheck >/dev/null; then
					cppcheck "$file" || return 1
				else
					log "[OK] will not check '$mimetype' file '$file'" debug
				fi
			;;
			'application/javascript')
				# TODO:
				# http://stackoverflow.com/questions/1802478/running-v8-javascript-engine-standalone
				# http://www.quora.com/What-can-be-used-to-unit-test-JavaScript-from-the-command-line
				log "[OK] will not check '$mimetype' file '$file'" debug
			;;
			'image/gif')
				# imagemagick?
				log "[OK] will not check gfx file '$file'" debug
			;;
			'application/octet-stream'|'application/x-gzip'|'text/x-diff'|'application/x-executable')
				log "[OK] will not check binary file '$file'" debug
			;;
			'text/x-shellscript'|'text/plain')
				sh -n "$file" || {
					log "error in file '$file' - abort"
					rm "$tempfile"
					return 1
				}
				i=$(( $i + 1 ))
			;;
			*)
				log "unknown mimetype: '$mimetype' file: '$file'"
				rm "$tempfile"
				return 1
			;;
		esac
	} done <"$tempfile"

	log "[OK] checked $i files"
	rm "$tempfile"
	return 0
}

unittest_do()
{
	local funcname='unittest_do'
	local shellcheck_bin build_loader file

	if [ "$KALUA_DIRNAME" = 'openwrt-build' ]; then
		build_loader='openwrt-addons/etc/kalua_init'
	else
		build_loader="$KALUA_DIRNAME/openwrt-addons/etc/kalua_init"
	fi

	log '[START]'
	log "building loader: $build_loader"
	$build_loader || return 1

	sh -n '/tmp/loader' && {
		log '. /tmp/loader'
		. /tmp/loader

		log 'echo "$HARDWARE" + "$SHELL" + "$USER" + cpu + diskspace'
		echo "'$HARDWARE' + '$SHELL' + '$USER'"
		grep -c ^'processor' '/proc/cpuinfo'
		df -h

		log '_ | wc -l'
		_ | wc -l

		log '_net get_external_ip'
		_net get_external_ip

		log 'list="$( ls -1R . )"'
		local list="$( ls -1R . )"

		log '_list count_elements "$list"'
		_list count_elements "$list" || return 1

		log '_list random_element "$list"'
		_list random_element "$list" || return 1

		log "_system architecture"
		_system architecture || return 1

		log "_system ram_free"
		_system ram_free || return 1

		log '_filetype detect_mimetype /tmp/loader'
		_filetype detect_mimetype /tmp/loader || return 1

		log '_system load 1min full ; _system load'
		_system load 1min full || return 1
		_system load || return 1

		[ -n "$TRAVIS" ] && {
			wget -O 'shellsheck.deb' 'http://ftp.debian.org/debian/pool/main/s/shellcheck/shellcheck_0.3.5-2_amd64.deb'
			sudo dpkg -i 'shellsheck.deb'
		}

		shellcheck_bin="$( which shellcheck )"
		[ -e ~/.cabal/bin/shellcheck ] && shellcheck_bin=~/.cabal/bin/shellcheck

		if [ -z "$shellcheck_bin" ]; then
			log "[OK] shellcheck not installed - no deeper tests"
		else
			log "testing with '$shellcheck_bin'"

			# strip non-ascii: tr -cd '\11\12\15\40-\176' <"$file" >"$newfile"
			for file in openwrt-addons/www/cgi-bin-404.sh; do {
				$shellcheck_bin -e SC2034,SC2046,SC2086 "$file" || return 1
#				$shellcheck_bin -e SC1010,SC2086,SC2154 openwrt-addons/etc/kalua/wget || return 1
				log "[OK] shellcheck: $file"
			} done
		fi

		sloc()
		{
			log "counting lines of code:"

			sloccount . | while read line; do {
				case "$line" in
					[0-9]*|*'%)'|*'):'|*' = '*|'SLOC '*)
						# only show interesting lines
						echo "$line"
					;;
				esac
			} done
		}

		if which sloccount; then
			sloc
		else
			if [ -n "$TRAVIS" ]; then
				sudo apt-get -y install sloccount
				sloc
			else
				log '[OK] sloccount not installed'
			fi
		fi

		log 'cleanup'
		rm -fR /tmp/loader /tmp/kalua

		log '[READY]'
	}
}

check_git_settings()
{
	local funcname='check_git_settings'

	# TODO: only relevant, if we want to commit something?
	git config --global user.email >/dev/null || {
		log "please set: git config --global user.email 'your@email.tld'"
		return 1
	}

	git config --global user.name  >/dev/null || {
		log "please set: git config --global user.name 'Your Name'"
		return 1
	}
}

# kalua/openwrt-build/build.sh		-> kalua
# weimarnetz/openwrt-build/build.sh	-> weimarnetz
# openwrt-build/build.sh		-> openwrt-build
KALUA_DIRNAME="$( echo "$0" | cut -d'/' -f1 )"
PATCHDIR=

[ -z "$1" ] && print_usage_and_exit

while [ -n "$1" ]; do {
	case "$1" in
		"--${KALUA_DIRNAME}_package"|'-P')
			build_tarball_package || print_usage_and_exit
			exit 0
		;;
		'--info'|'-i')
			target_hardware_set "${2:-$( cat files/etc/HARDWARE )}" info
			exit 0
		;;
		'--check'|'-c')
			if [ "$KALUA_DIRNAME" = "$( dirname "$0" )" ]; then
				# openwrt-build/build.sh -> openwrt-build
				check_scripts .
			else
				check_scripts ${2:-$KALUA_DIRNAME}
			fi

			test $? -eq 0 || exit 1
			STOP_PARSE='true'
		;;
		'--unittest')
			unittest_do

			test $? -eq 0 || exit 1
			STOP_PARSE='true'
		;;
		'--help'|'-h')
			print_usage_and_exit
		;;
		'--patchdir')
			PATCHDIR="$PATCHDIR $2"
		;;
		'--force'|'-f')
			FORCE='true'
		;;
		'--fail')
			FAIL='true'
		;;
		'--openwrt')
			case "$2" in
				'trunk'|'12.09'|'14.07'|'15.05'|'r'[0-9]*)
					VERSION_OPENWRT="$2"
				;;
				*)
					log '[ERR] please specify: --openwrt trunk|12.09|14.07|15.05 or e.g. r12345'
					STOP_PARSE='true'
				;;
			esac
		;;
		'--kernel'|'-k')
			VERSION_KERNEL_FORCE="$2"
		;;
		'--hardware'|'-hw')
			if target_hardware_set 'list' 'plain' | grep -q ^"$2"$ ; then
				HARDWARE_MODEL="$2"
			else
				# ARG3 = e.g. option 'plain' or 'js'
				case "$3-$2" in
					plain-[0-9]*|*-[0-9]*)
						# e.g. 1043 -> only list models with this number
						target_hardware_set 'list' "$3" | fgrep "$2"
					;;
					*)
						target_hardware_set 'list' "$3"
					;;
				esac

				exit 1
			fi
		;;
		'--usecase'|'-u')
			for LIST_USER_OPTIONS in $( serialize_comma_list "${2:-help}" ); do {
				OPTION_SHORT="$LIST_USER_OPTIONS"
				OPTION_SHORT="$( echo "$OPTION_SHORT" | cut -d'@' -f1 )"	# e.g. kalua@$githash
				OPTION_SHORT="$( echo "$OPTION_SHORT" | cut -d'-' -f1 )"	# e.g. WiFi-$symbolname

				if build_options_set 'list' 'plain' | grep -q ^"$OPTION_SHORT"$ ; then
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
					log "[ERROR] --release stable|beta|testing"
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
		'--buildid')
			# e.g. 'user@domain.tld'
			# http://tjworld.net/wiki/Linux/Kernel/Build/CustomiseVersionString
			log "[OK] $1: set $2 via fake hostname/whoami in ~"

			echo    >~/whoami '#!/bin/sh'
			echo   >>~/whoami "echo $( echo "$2" | cut -d'@' -f1 )"
			chmod +x ~/whoami

			echo    >~/hostname '#!/bin/sh'
			echo   >>~/hostname "echo $( echo "$2" | cut -d'@' -f2 )"
			chmod +x ~/hostname

			case "$PATH" in
				'~:'*)
				;;
				*)
					log "[ERR] $1: adjust your path with: export PATH=\"~:\$PATH\""
					STOP_PARSE='true'
				;;
			esac
		;;
	esac

	shift
} done

[ -n "$STOP_PARSE" ] && exit 0
read T1 REST </proc/uptime

die_and_exit()
{
	[ -n "$FORCE" ] && return 0

	log
	log '[ERROR] the brave can try --force, all others should do: git checkout master'
	exit 1
}

check_git_settings			|| die_and_exit
check_working_directory			|| die_and_exit
openwrt_download "$VERSION_OPENWRT"	|| die_and_exit

[ -z "$HARDWARE_MODEL" ]    && print_usage_and_exit "you forgot to specifiy --hardware '\$MODEL'"
[ -z "$LIST_USER_OPTIONS" ] && print_usage_and_exit "you forgot to specifiy --usecase '\$USECASE'"

SPECIAL_OPTIONS=
target_hardware_set "$HARDWARE_MODEL"	|| die_and_exit
copy_additional_packages		|| die_and_exit
build_options_set "$SPECIAL_OPTIONS"	|| die_and_exit
build_options_set "$LIST_USER_OPTIONS"	|| die_and_exit
build					|| exit 1
copy_firmware_files			|| die_and_exit
openwrt_download 'switch_to_master'

read T2 REST </proc/uptime

log "[OK] - Jauchzet und frohlocket, ob der Bytes die erschaffen wurden in $( calc_time_diff "$T1" "$T2" ) sek."
target_hardware_set "$HARDWARE_MODEL" info quiet >/dev/null && log "[OK] - more info via: $0 --info '$HARDWARE_MODEL'"
log "[OK] - check size of files with: find bin/$ARCH -type f -exec stat -c '%s %N' {} \; | sort -n"

exit 0
