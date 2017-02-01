#!/bin/sh

# TODO:
# - own codefile for 'usecase' and 'hardware'?
# - force feed via --feed XY --feed AB
# - only add feedXY if usecase needs it -> feed-dependency in usecase
# - simulate apply-run: show symbols/tree
# - usecases: noUSB, noIPTables, noIPv6, Failsafe (like sven-ola -> via kernel-commandline), noJFFS2, noSQFS
# - build release-dir
# - autodeps for kalua-functions and strip unneeded ones, when e.g. db() is not needed?
# - include/renew patches for awk-removal
# - qemu: network: https://gist.github.com/yousong/8d94c6823a2a6f0f79fd

print_usage_and_exit()
{
	local hint="$1"
	local rev="$( openwrt_revision_number_get )"
	local hardware usecase more_options

	[ -x "$0" ] || {
		log "[OK] executing for you: 'chmod +x $0'"
		chmod +x "$0"
	}

	# format: $USECASE $HARDWARE_MODEL
	if [ -e 'KALUA_HISTORY' ]; then
		# last used one
		set -- $( tail -n1 'KALUA_HISTORY' )
		shift
		hardware="$*"
	else
		hardware="$( target_hardware_set 'list' 'plain' | head -n1 )"
	fi

	# format: $USECASE $HARDWARE_MODEL
	if [ -e 'KALUA_HISTORY' ]; then
		# last used one, e.g.: Standard,noPPPoE,BigBrother,kalua@e678dd6
		usecase="$( tail -n1 'KALUA_HISTORY' | cut -d' ' -f1 )"
		usecase="$( echo "$usecase" | cut -d'@' -f1 )"
	else
		usecase="Standard,$KALUA_DIRNAME"
	fi

	# these are used by the OpenWrt build scripts
	[ -e ~/whoami -a -e ~/hostname ] && {
		more_options="--buildid '$( tail -n1 ~/whoami | cut -d' ' -f2 )@$( tail -n1 ~/hostname | cut -d' ' -f2 )'"
	}

	[ -n "$hint" ] && log "[HINT:] $hint"

	if [ -e 'build.sh' ]; then
		# virgin script-download
		cat <<EOF

Usage: ./$0 --openwrt
       ./$0 --openwrt lede|trunk|lede-staging
       ./$0 --openwrt lede --download_pool /absolute/path/to/dir
       ./$0 --openwrt 15.05 --myrepo git://github.com/weimarnetz/weimarnetz.git

       This will download/checkout OpenWrt-buildscripts,
       and 'myrepo' defaults to '$KALUA_REPO_URL'.

EOF
	else
		cat <<EOF

Usage: $0 --openwrt <revision> --hardware <model> --usecase <meta_names> [--debug] [--force] [--quiet]

 e.g.: $0 --openwrt r${rev:-12345} --hardware '$hardware' --usecase '$usecase' $more_options
       or:
       $0 --openwrt r${rev:-12345} --hardware '$hardware' --usecase 'freifunk,$KALUA_DIRNAME' $more_options
       $0 --openwrt r${rev:-12345} --hardware '$hardware' --usecase 'freifunk-4mb,$KALUA_DIRNAME' $more_options
       $0 --openwrt r${rev:-12345} --hardware '4mb_model' --usecase 'Small,noHTTPd,noSSH,noOPKG,noPPPoE,noDebug,OLSRd,$KALUA_DIRNAME'
       $0 --openwrt r${rev:-12345} --hardware '8mb_model' --usecase 'Standard,$KALUA_DIRNAME'

get help without args, e.g.: --hardware <empty> or
			     --hardware 'substring'
special arguments:
	  # continuous integration / development
	  --check 	# shell-scripts only
	  --unittest	# complete testsuite
	  --fail	# simulate error: keep patched branch after building
	  --nobuild	# stop after patching and building .config
	  --update	# refresh this buildscript
	  --dotconfig "\$myfile"
	  --feedstime '2015-08-31 19:33' 'feedsname or <empty>'

	  # apply own patches on top of OpenWrt. default only adds openwrt-patches/*
          --patchdir \$dir1 --patchdir \$dir2

	  # add own servertring to image in dmesg/uname
	  --buildid user@domain.tld

	  # enforce specific kernel, see 'include/kernel-version.mk'
	  --kernel 3.18

	  # enforce specific apply_profile configuration/nodenumber
	  --profile ffweimar.hybrid.120

	  # build .ipk-package from 'myrepo'
	  --tarball_package

	  # autoupload to release-server
	  --release 'stable' 'user@server:/your/path'

EOF
	fi

	test -n "$FORCE"
	exit $?
}

build_tarball_package()
{
	local funcname='build_tarball_package'

	[ "$KALUA_DIRNAME" = 'openwrt-build' ] && {
		log "wrong path, i do not want to see 'openwrt-build'"
		return 1
	}

	local architecture='all'
	local package_name="$KALUA_DIRNAME-framework"
	local kalua_unixtime="$( cd $KALUA_DIRNAME || return; git log -1 --pretty='format:%ct'; cd .. )"
	local package_version=$(( kalua_unixtime / 3600 ))
	local file_tarball="${package_name}_${package_version}_${architecture}.ipk"

	local builddir="$KALUA_DIRNAME/builddir"
	local destdir="bin/${ARCH:-$architecture}/packages"
	local verbose="${DEBUG+v}"
	local tar_flags="-c${verbose}zf"
	local tar_options='--owner=root --group=root'

	mkdir "$builddir" || return 1
	cd "$builddir" || return

	echo '2.0' >'debian-binary'

	cat >'control' <<EOF
Package: $package_name
Priority: optional
Version: $package_version
Maintainer: Bastian Bittorf <kontakt@weimarnetz.de>
Section: utils
Description: some helper scripts for making life easier on meshed OpenWrt nodes
Architecture: $architecture
Source: $KALUA_REPO_URL / $funcname()
EOF

	tar $tar_options $tar_flags 'control.tar.gz' ./control
	tar $tar_options $tar_flags 'data.tar.gz' -C ../openwrt-addons $( ls -1 ../openwrt-addons )
	tar $tar_options $tar_flags "$file_tarball" ./debian-binary ./control.tar.gz ./data.tar.gz
	rm 'control' 'debian-binary'

	cd ..
	cd ..

	log "timestamp of latest commit: $kalua_unixtime / 3600 = $package_version"
	log "moving '$file_tarball' from dir '$builddir' to '$destdir'"

	mkdir -p "$destdir"
	mv "$builddir/$file_tarball" "$destdir"
	rm -fR "$builddir"
	ls -l "$destdir/$file_tarball"
}

autocommit()
{
	local gitfile="$1"	# existing_file or 'git revert xy'
	local message="$2"
	local count_files count_dirs count filetype line file

	if [ -e "$gitfile" ]; then
		# we need 'force' here, because e.g. files/ is in .gitignore
		git add --force "$gitfile" || {
			log "[ERROR] during 'git add --force '$file'"
			git stash save 'unsure what happened'
			return 1
		}

		count_files=$( find "$gitfile" -type f | wc -l )
		count_dirs=$(  find "$gitfile" -type d | wc -l )
		count="($count_files files$( test $count_dirs -gt 0 && echo " and $count_dirs dirs" ))"
		filetype="$( test -d "$gitfile" && echo 'directory' || echo 'file' )"
	else
		eval $gitfile || {
			case "$gitfile" in
				*'git revert '*)
					log "[ERR] command failed (but ignoring it): eval $gitfile"
					return 0
				;;
			esac

			log "[ERR] command failed: eval $gitfile"
			# workaround for a conflicting merge/revert

			git status | grep 'both modified:' | while read -r line; do {
				# e.g.: #  both modified:  package/network/services/dropbear/Makefile
				set -- $line
				shift 3
				file="$*"

				log "git-tricky: fetching newest version of '$file'"
				git checkout HEAD~1 -- "$file"
				git add --force "$file"
			} done
		}

		[ -z "$message" ] && message="$gitfile"
	fi

	# see: build_options_set() with option 'ready'
	[ "$gitfile" = 'files/etc/openwrt_build.details' ] || {
		mkdir -p 'files/etc'
		echo "patch: $message | $gitfile | $count" >>'files/etc/openwrt_build.details'
	}
	git add --force 'files/etc/openwrt_build.details'

	git commit --signoff -m "
autocommit: $message
| $filetype: $gitfile $count

# mimic OpenWrt-style: (is unrolled after clean build)
git-svn-id: based_on_OpenWrt@$VERSION_OPENWRT_INTEGER" |
	grep -v ^' create mode'
}

log()
{
	local message="$1"	# special handling, if it contains '[ERROR]'
	local option="$2"	# e.g. debug,gitadd,untrack
	local gitfile="$3"	# can also be a directory
	local name

	# each function should define it
	[ -z "$funcname" ] && local funcname='unset_funcname'

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
		if [ -e "$gitfile" ]; then
			# TODO: silence git output in 'debug' mode
			autocommit "$gitfile" "$message" && {
				has "$option" 'untrack' && git rm --cached "$gitfile"
			}
		else
			if git rm "$gitfile"; then
				autocommit "$gitfile" "$message"
			else
				log "gitadd: file/dir '$gitfile' does not exist"
			fi
		fi
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

	# set global var on 1st run
	[ -z "$MYLOGGER" ] && {
		if logger -s -- "$0:firstrun testing_feature_s" 2>/dev/null; then
			MYLOGGER='logger -p user.info -s'
		else
			# e.g. AIX power-aix 1 7 00F84C0C4C00
			MYLOGGER='echo'
		fi
	}

	case "$message" in
		*'[ERROR]'*)
			$MYLOGGER '! L'
			$MYLOGGER "!  )- $0: $message"
			$MYLOGGER '! /'
		;;
		*)
			$MYLOGGER "$0:$name $message"
		;;
	esac
}

search_and_replace()		# workaround 'sed -i' which is a GNU extension and not POSIX
{				# http://stackoverflow.com/questions/7232797/sed-on-aix-does-not-recognize-i-flag
	local file="$1"
	local search="$2"	# ^LINUX_VERSION:=.*
	local replace="$3"	# LINUX_VERSION:=3.18.19
	local pattern

	[ -e "$file" ] || {
		log "[ERROR] search_and_replace() file not found: '$file'"
		return 1
	}

	sed >"$file.tmp" "s|$search|$replace|" "$file" || {
		log "[ERROR] while replacing '$search' with '$replace' in '$file'"
		rm "$file.tmp"
		return 1
	}

	if cmp "$file" "$file.tmp" >/dev/null; then
		rm "$file.tmp"
		log "[ERROR] replacing did not work, there was no change in '$file.tmp'"
		return 1
	else
		mv "$file.tmp" "$file"
	fi
}

kconfig_file()
{
	# TODO: code duplication see function below
	local dir arch

	dir="target/linux/$ARCH_MAIN"
	[ -d "$dir" ] || {
		log "[ERR] kconfig_file() dir not found: '$dir'"
		return 1
	}

	case "$ARCH_MAIN" in
		'uml')
			# target/linux/uml/config/i386|x86_64
			arch="$( buildhost_arch )"
			[ "$arch" = 'amd64' ] && arch='x86_64'

			find "$dir/config/$arch" -type f
		;;
		*)
			# config-3.10
			log "kconfig_file() dir: '$dir/config-*'"
			find "$dir" -type f -name 'config-[0-9]*' | head -n1
		;;
	esac
}

kernel_commandline_tweak()	# https://lists.openwrt.org/pipermail/openwrt-devel/2012-August/016430.html
{
	local funcname='kernel_commandline_tweak'
	local dir="target/linux/$ARCH_MAIN"
	local pattern=' oops=panic panic=10 '
	local config kernelversion

	case "$ARCH_MAIN" in
		'uml')
			return 0
		;;
		'mpc85xx')
			config="$dir/files/arch/powerpc/boot/dts/tl-wdr4900-v1.dts"	# since r45597

			if [ -e "$config" ];then
				:
			else
				# config-3.10 -> 3.10
				kernelversion="$( find "$dir" -name 'config-[0-9]*' | head -n1 | cut -d'-' -f2 )"
				config="$dir/patches-$kernelversion/140-powerpc-85xx-tl-wdr4900-v1-support.patch"
			fi

			grep -Fq "$pattern" "$config" || {
				search_and_replace "$config" 'console=ttyS0,115200' "$pattern &"
				log "looking into '$config', adding '$pattern'" gitadd "$config"
			}
		;;
		'ar71xx')
			config="$dir/image/Makefile"

			grep -Fq "$pattern" "$config" || {
				search_and_replace "$config" 'console=' "$pattern &"
				log "looking into '$config', adding '$pattern'" gitadd "$config"
			}
		;;
		*)
			# see also: https://dev.openwrt.org/changeset/46754/trunk ...46760
			# tested for brcm47xx
			config="$( find "$dir" -name 'config-[0-9]*' | head -n1 )"

			if [ -e "$config" ]; then
				log "looking into '$config', adding '$pattern'"

				grep -Fq "$pattern" "$config" || {
					# FIXME! use search_and_replace()
					sed >"$config.tmp" "/^CONFIG_CMDLINE=/s/\"$/${pattern}\"/" "$config"
					mv   "$config.tmp" "$config"
					log "looking into '$config', adding '$pattern'" gitadd "$config"
				}
			else
				log "cannot find '$config' from '$dir/config-*'"
			fi
		;;
	esac

	grep -q "$pattern" "$config" || {
		log "[ERROR] while adding '$pattern' to '$config'"
	}
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
	local dir="$KALUA_DIRNAME/openwrt-patches/interesting/minstrel-rhapsody"
	local kernel_dir='package/kernel/mac80211'
	local file

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
	local file="$KALUA_DIRNAME/openwrt-patches/reghack/900-regulatory-compliance_test.patch"
	local file_regdb_hacked countries code file2 pattern COMPAT_WIRELESS_DATE

	if [ -e "$file" ]; then
		MAC80211_CLEAN='true'
		COMPAT_WIRELESS_DATE="$( grep -F 'PKG_VERSION:=' 'package/kernel/mac80211/Makefile' | cut -d'=' -f2 )"	# e.g. 2016-01-10
		pattern="${option}CONFIG_PACKAGE_kmod-ath9k=y"

		log "searching for '$pattern' in '.config'"
		if grep -q "$pattern" '.config'; then
			cp -v "$file" "package/kernel/mac80211/patches"
			file2="package/kernel/mac80211/patches/$( basename "$file" )"
			search_and_replace "$file2" 'YYYY-MM-DD' "$COMPAT_WIRELESS_DATE"
			log "patching ath9k/compat-wireless $COMPAT_WIRELESS_DATE for using all channels ('birdkiller-mode')" gitadd "$file2"

			if [ $VERSION_OPENWRT_INTEGER -lt 40293 ]; then
				file_regdb_hacked="$KALUA_DIRNAME/openwrt-patches/reghack/regulatory.db.txt"
			else
				file_regdb_hacked="$KALUA_DIRNAME/openwrt-patches/reghack/regulatory.db.txt-r40293++"
			fi

			file2='package/kernel/mac80211/files/regdb.txt'
			cp -v "$file_regdb_hacked" "$file2"
			log "using another regdb: '$file_regdb_hacked'" gitadd "$file2"

			# e.g. '00 US FM'
			countries="$( grep ^'country ' "$file_regdb_hacked" | cut -d' ' -f2 | cut -d':' -f1 )"
			countries="$( echo "$countries" | while read -r code; do printf '%s' "$code "; done )"		# remove CR/LF
			log "using another regdb: '$file_regdb_hacked' for $countries" gitadd "$file2"

			register_patch "REGHACK: valid countries: $countries"
			register_patch "$file"
			register_patch "$file_regdb_hacked"
		else
			log "cannot find '$pattern' in '.config', removing patches (if any) file: '$file'"
			file="$( basename "$file" )"

			[ -e 'package/kernel/mac80211/files/regdb.txt_old' ] && {
				cp -v 'package/kernel/mac80211/files/regdb.txt_original' 'package/kernel/mac80211/files/regdb.txt'
			}

			[ -e "package/kernel/mac80211/patches/$file" ] && {
				rm -v "package/kernel/mac80211/patches/$file"
			}
		fi
	else
		log "[ERR] cannot find '$file'"
	fi
}

copy_additional_packages()
{
	local funcname='copy_additional_packages'
	local dir install_section file package

	for dir in $KALUA_DIRNAME/openwrt-packages/* ; do {
		if [ -e "$dir/Makefile" ]; then
			install_section="$( grep -F 'SECTION:=' "$dir/Makefile" | cut -d'=' -f2 )"
			package="$( basename "$dir" )"

			do_copy()
			{
				log "working on '$dir', destination: '$install_section'"
				cp -Rv "$dir" "package/$install_section"
				log "whole dir" gitadd "package/$install_section"
			}

			if [ "$package" = 'cgminer' ]; then
				usecase_has 'BTCminerCPU' && {
					do_copy

					file="package/$install_section/$package/Makefile"
					search_and_replace "$file" 'PKG_REV:=.*' 'PKG_REV:=1a8bfad0a0be6ccbb2cc88917d233ac5db08a02b'
					search_and_replace "$file" 'PKG_VERSION:=.*' 'PKG_VERSION:=2.11.3'
					search_and_replace "$file" '--enable-bflsc' '--enable-cpumining'
					log "cgminer" gitadd "$file"
				}
			else
				do_copy
			fi
		else
			echo
			log "no Makefile found in '$dir' - please check"
			return 0
		fi
	} done

	return 0
}

version_is_lede()
{
	case "$( git config --get remote.origin.url )" in
		*'lede-project'*)
			return 0
		;;
		*)
			return 1
		;;
	esac
}

target_hardware_set()
{
	local funcname='target_hardware_set'
	local model="$1"	# 'list' or <modelname>
	local option="$2"	# 'plain', 'js', 'info' or <empty>
	local quiet="$3"	# e.g. 'quiet' (not logging)
	local line file version device_symbol

	[ -n "$quiet" ] && funcname="quiet_$funcname"

	# must match ' v[0-9]' and will be e.g.
	# ' v7' -> '7' or ' v1.5' -> '1.5' and defaults to '1'
	version="$( echo "$model" | sed -n 's/^.* v\([0-9\.]*\)$/\1/p' )"
	[ -z "$version" ] && version='1'

	case "$model" in
		'UML')
			# TODO: rename 'vmlinux' to e.g. 'openwrt-uml-r12345' (better readable tasklist)
			# TODO: rename 'ext4-img' to rootfs?
			TARGET_SYMBOL='CONFIG_TARGET_uml_Default=y'
			FILENAME_SYSUPGRADE='openwrt-uml-vmlinux'
			FILENAME_FACTORY='openwrt-uml-ext4.img'
			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_ROOTFS_PARTSIZE=16"	# [megabytes]

			# TODO: CONFIG_TARGET_ROOTFS_SQUASHFS=y -> CONFIG_TARGET_ROOTFS_EXT4FS is not set ?

			[ "$option" = 'info' ] && {
				cat <<EOF
# simple boot via:
bin/uml/$FILENAME_SYSUPGRADE ubd0=bin/uml/$FILENAME_FACTORY eth8=tuntap,,,192.168.0.254 oops=panic panic=10
or
bin/targets/uml/generic/$FILENAME_SYSUPGRADE ubd0=bin/targets/uml/generic/$FILENAME_FACTORY eth8=tuntap,,,192.168.0.254 oops=panic panic=10

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
		'x86_64')
			TARGET_SYMBOL='CONFIG_TARGET_x86_64=y'
			FILENAME_SYSUPGRADE='openwrt-x86-64-vmlinuz'
			FILENAME_FACTORY='openwrt-x86-64-rootfs-ext4.img.gz'
			[ ${#LIST_USER_OPTIONS} -le 14 ] && {
				# e.g. 'Standard,kalua' or 'Small,kalua' ...
				SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_ROOTFS_PARTSIZE=16"	# [megabytes]
			}	# parser_ignore

			[ "$option" = 'info' ] && {
				cat <<EOF
# simulated SCSI-drive (see https://dev.openwrt.org/ticket/17947)
qemu-system-x86_64 -nographic -drive file=bin/x86/$FILENAME_FACTORY,if=none,id=mydisk -device ich9-ahci,id=ahci -device ide-drive,drive=mydisk,bus=ahci.0
# and with networking
# TODO: http://www.linux-kvm.org/page/Networking#iptables.2Frouting
EOF
				return 0
			}	# parser_ignore
		;;
		'Cubietruck')
			# aka: 'Cubieboard 3'
			#
			# https://wiki.openwrt.org/doc/hardware/soc/soc.allwinner.sunxi
			# http://linux-sunxi.org/Cubieboard/FAQ
			# http://docs.armbian.com/Hardware_Allwinner-A20/
			# http://www.armbian.com/cubietruck/
			# http://linux-sunxi.org/Sunxi_devices_as_NAS
			#
			# NAND-install:
			# http://linux-sunxi.org/Cubieboard/Installing_on_NAND
			# http://www.cubieforums.com/index.php?topic=555.0
			#
			# sd-card install:
			# http://wiki.openwrt.org/doc/hardware/soc/soc.allwinner.sunxi#sd_layout
			TARGET_SYMBOL='CONFIG_TARGET_sunxi_Cubietruck=y'
			FILENAME_SYSUPGRADE='openwrt-sunxi-Cubietruck-sdcard-vfat-ext4.img.gz'
			# CONFIG_BRCMFMAC_SDIO=y
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
		'MQmaker WiTi')
			# https://wiki.openwrt.org/toh/mqmaker/witi
			TARGET_SYMBOL='CONFIG_TARGET_ramips_mt7621_witi=y'
			FILENAME_SYSUPGRADE='openwrt-ramips-mt7621-witi-squashfs-sysupgrade.bin'
			FILENAME_FACTORY="$FILENAME_SYSUPGRADE"
		;;
		'Xiaomi Miwifi mini')
			# https://wiki.openwrt.org/toh/xiaomi/mini
			TARGET_SYMBOL='CONFIG_TARGET_ramips_mt7620_MIWIFI-MINI=y'
			FILENAME_SYSUPGRADE='openwrt-ramips-mt7620-miwifi-mini-squashfs-sysupgrade.bin'
			FILENAME_FACTORY="$FILENAME_SYSUPGRADE"
		;;
		'Buffalo WZR-HP-AG300H')
			# http://wiki.openwrt.org/toh/buffalo/wzr-hp-ag300h
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_WZRHPAG300H=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-wzr-hp-ag300h-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-wzr-hp-ag300h-squashfs-factory.bin'
			# TODO: openwrt-ar71xx-generic-wzr-hp-ag300h-squashfs-tftp.bin
		;;
		'TP-LINK CPE210'|'TP-LINK CPE220')
			# https://wiki.openwrt.org/toh/tp-link/tl-cpe210
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_CPE510=y'	# really 510
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-cpe210-220-510-520-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-cpe210-220-510-520-squashfs-factory.bin'
		;;
		'TP-LINK CPE510'|'TP-LINK CPE520')
	# TODO: https://git.lede-project.org/?p=source.git;a=commit;h=c2e0c41842895ba47819fa98b785c76a2524628b
			# https://wiki.openwrt.org/toh/tp-link/tl-cpe510
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_CPE510=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-cpe210-220-510-520-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-cpe210-220-510-520-squashfs-factory.bin'
		;;
		'TP-LINK TL-WR703N v1')
			# http://wiki.openwrt.org/toh/tp-link/tl-wr703n
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR703=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-factory.bin'

#			MAX_SIZE='3.735.556'	# 57 erase-blocks * 64k + 4 bytes padding = 3.735.552 -> klog: jffs2: Too few erase blocks (4)
#			confirmed: 3.604.484 = ok
#			MAX_SIZE=$(( 56 * 65536 ))
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
		'TP-LINK TL-WR841N/ND v1.5'|'TP-LINK TL-WR841N/ND v3'|'TP-LINK TL-WR841N/ND v5'|'TP-LINK TL-WR841N/ND v7')
			# http://wiki.openwrt.org/de/toh/tp-link/tl-wr841nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR841=y'
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-tl-wr841nd-v${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-tl-wr841nd-v${version}-squashfs-factory.bin"
		;;
		'TP-LINK TL-WR841N/ND v8'|'TP-LINK TL-WR841N/ND v9')
			# http://wiki.openwrt.org/de/toh/tp-link/tl-wr841nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR841=y'
			# TODO: name changed: openwrt-ar71xx-generic-tl-wr841-v8-squashfs-sysupgrade.bin
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-tl-wr841n-v${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-tl-wr841n-v${version}-squashfs-factory.bin"
		;;
		'TP-LINK TL-WR842N/ND v1'|'TP-LINK TL-WR842N/ND v2')
			# https://wiki.openwrt.org/toh/tp-link/tl-wr842nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR842=y'
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-tl-wr842n-v${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-tl-wr842n-v${version}-squashfs-factory.bin"
		;;
		'TP-LINK TL-WR847N v8')
			# http://wiki.openwrt.org/de/toh/tp-link/tl-wr841nd
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR841=y'
			FILENAME_SYSUPGRADE="openwrt-ar71xx-generic-tl-wr847n-v8-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ar71xx-generic-tl-wr847n-v8-squashfs-factory.bin"
		;;
		'TP-LINK TL-WDR3600')
			# http://wiki.openwrt.org/toh/tp-link/tl-wdr3600
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWDR3600=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wdr3600-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wdr3600-v1-squashfs-factory.bin'
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
			# TODO: CONFIG_PACKAGE_ath10k-firmware-qca988x-ct=y
			# qca988x hw2.0 target 0x4100016c chip_id 0x043202ff sub 0000:0000
			# /lib/firmware/ath10k/QCA988X/hw2.0/
			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_PACKAGE_kmod-ath10k=y"
		;;
		'Mercury MAC1200R')
			# http://wiki.openwrt.org/toh/mercury/mac1200r
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_MAC1200R=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-mc-mac1200r-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-mc-mac1200r-squashfs-factory.bin'
		;;
		'D-Link DIR-505 A1'|'D-Link DIR-505L A1'|'D-Link DIR-505L A2')
			# https://wiki.openwrt.org/toh/d-link/dir-505
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_DIR505A1=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-dir-505-a1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-dir-505-a1-squashfs-factory.bin'
		;;
		'D-Link DIR-615-E4')
			# https://dev.openwrt.org/ticket/20522
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_DIR615E4=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-dir-615-e4-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-dir-615-e4-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation2'|'Ubiquiti Picostation2'|'Ubiquiti Bullet2')
			# Atheros MIPS 4Kc @ 180 MHz / ath5k / 32 mb RAM / 8 mb FLASH
			# the other one is: Picostation M2 (HP) = MIPS 24KC / 400 MHz
			if [ $( openwrt_revision_number_get ) -ge 44736 ]; then
				TARGET_SYMBOL='CONFIG_TARGET_ath25=y'
			else
				TARGET_SYMBOL='CONFIG_TARGET_atheros_Default=y'
			fi

			FILENAME_SYSUPGRADE='openwrt-atheros-combined.squashfs.img'
			FILENAME_FACTORY='openwrt-atheros-ubnt2-pico2-squashfs.bin'
		;;
		'Ubiquiti Nanostation5'|'Ubiquiti Picostation5'|'Ubiquiti Bullet5'|'Ubiquiti WispStation5')
			# Atheros MIPS 4Kc / ath5k / 32 mb RAM / 8 mb FLASH (Wispstation5 = 16/4)
			if [ $( openwrt_revision_number_get ) -ge 44736 ]; then
				TARGET_SYMBOL='CONFIG_TARGET_ath25=y'
			else
				TARGET_SYMBOL='CONFIG_TARGET_atheros_Default=y'
			fi

			FILENAME_SYSUPGRADE='openwrt-atheros-combined.squashfs.img'
			FILENAME_FACTORY='openwrt-atheros-ubnt5-squashfs.bin'
		;;
		'Ubiquiti Bullet M2'|'Ubiquiti Bullet M2 Titanium'|'Ubiquiti Bullet M5'|'Ubiquiti Bullet M5 Titanium'|'Ubiquiti Picostation M2'|'Ubiquiti Picostation M5')
			# http://wiki.openwrt.org/toh/ubiquiti/bullet
			# http://wiki.openwrt.org/toh/ubiquiti/picostationm2
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_UBNT=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-bullet-m-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation M2'|'Ubiquiti Nanostation M5')
			# XM (older model)
			TARGET_SYMBOL="CONFIG_TARGET_ar71xx_generic_UBNT=y"
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-nano-m-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-nano-m-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation M2 XW'|'Ubiquiti Nanostation M5 XW')
			# XW (since 2014)
			# http://wiki.openwrt.org/toh/ubiquiti/nanostationm5
			TARGET_SYMBOL="CONFIG_TARGET_ar71xx_generic_UBNT=y"
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-nano-m-xw-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-nano-m-xw-squashfs-factory.bin'
		;;
		'Ubiquiti Nanostation Loco M2 XW'|'Ubiquiti Nanostation Loco M5 XW')
			# XW (since 2014)
			# http://wiki.openwrt.org/toh/ubiquiti/nanostationm5
			TARGET_SYMBOL="CONFIG_TARGET_ar71xx_generic_UBNT=y"
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-ubnt-loco-m-xw-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-ubnt-loco-m-xw-squashfs-factory.bin'
		;;
		'Targa WR-500-VoIP'|'Speedport W500V')
			TARGET_SYMBOL='CONFIG_TARGET_brcm63xx_generic=y'
			FILENAME_SYSUPGRADE='openwrt-brcm63xx-generic-SPW500V-squashfs-cfe.bin'
#			FILENAME_SYSUPGRADE='openwrt-SPW500V-squashfs-cfe.bin'
			FILENAME_FACTORY=
		;;
		'Linksys WRT1900AC v1')
			# https://wiki.openwrt.org/toh/linksys/wrt1900ac
			TARGET_SYMBOL="CONFIG_TARGET_mvebu_Caiman=y"
			FILENAME_SYSUPGRADE='openwrt-mvebu-armada-385-linksys-caiman-squashfs-sysupgrade.tar'
			FILENAME_FACTORY='openwrt-mvebu-armada-385-linksys-caiman-squashfs-factory.img'
		;;
		'Linksys WRT54G/GS/GL')
			TARGET_SYMBOL='CONFIG_TARGET_brcm47xx_legacy_Broadcom-b43=y'
			# image was 'openwrt-brcm47xx-squashfs.trx' in revision before r41530
			FILENAME_SYSUPGRADE='openwrt-brcm47xx-legacy-squashfs.trx'
			FILENAME_FACTORY='openwrt-wrt54g-squashfs.bin'

			SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_brcm47xx_legacy=y CONFIG_LOW_MEMORY_FOOTPRINT=y b43mini"
		;;
		'Buffalo WHR-HP-G54'|'Dell TrueMobile 2300'|'ASUS WL-500g Premium'|'ASUS WL-500g Premium v2'|'ASUS WL-HDD 2.5')
			TARGET_SYMBOL='CONFIG_TARGET_brcm47xx_Broadcom-b44-b43=y'

			if [ $( openwrt_revision_number_get ) -gt 41530 ]; then
				case "$model" in
					'ASUS WL-500g Premium')		# parser_ignore
						FILENAME_SYSUPGRADE='openwrt-brcm47xx-legacy-asus-wl-500gp-v1-squashfs.trx'
						FILENAME_FACTORY=''
					;;
					'ASUS WL-500g Premium v2')	# parser_ignore
						# TODO: needs the 'low power phy' compiled into b43
						FILENAME_SYSUPGRADE='openwrt-brcm47xx-legacy-asus-wl-500gp-v2-squashfs.trx'
						FILENAME_FACTORY=''
					;;
					*)
						FILENAME_SYSUPGRADE='openwrt-brcm47xx-generic-squashfs.trx'
						FILENAME_FACTORY='openwrt-brcm47xx-generic-squashfs.trx'
					;;
				esac

				SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_brcm47xx_legacy=y CONFIG_LOW_MEMORY_FOOTPRINT=y b43mini"
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
			TARGET_SYMBOL='CONFIG_TARGET_au1000_au1500_InternetBox=y'
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
		'Nexx WT3020A'|'Nexx WT3020H'|'Nexx WT3020F'|'Nexx WT3020AD')
			version='8M'
			[ "$model" = 'Nexx WT3020A' ] && version='4M'

			# http://wiki.openwrt.org/toh/nexx/wt3020
			TARGET_SYMBOL='CONFIG_TARGET_ramips_mt7620=y'
			FILENAME_SYSUPGRADE="openwrt-ramips-mt7620-wt3020-${version}-squashfs-sysupgrade.bin"
			FILENAME_FACTORY="openwrt-ramips-mt7620-wt3020-${version}-squashfs-factory.bin"
		;;
		'Mikrotik Routerboard 532')
			# http://wiki.openwrt.org/toh/mikrotik/rb532
			# PCI: 168C:001B Qualcomm Atheros AR5413/AR5414 Wireless Network Adapter [AR5006X(S) 802.11abg] = R52
			# http://www.dd-wrt.com/wiki/index.php/Mikrotik_Routerboard_RB/532
			### 1 x IDT Korina 10/100 Mbit/s Fast Ethernet port  supporting Auto-MDI/X
			### 2 x VIA VT6105 10/100 Mbit/s Fast Ethernet ports supporting Auto-MDI/X
			TARGET_SYMBOL='CONFIG_TARGET_rb532_Default=y'

			if version_is_lede ; then
				FILENAME_SYSUPGRADE='lede-rb532-nand-squashfs-sysupgrade.bin'
				FILENAME_FACTORY='lede-rb532-combined-squashfs.bin'
			else
				FILENAME_SYSUPGRADE='openwrt-rb532-combined-jffs2-128k.bin'
				FILENAME_FACTORY='openwrt-rb532-combined-jffs2-128k.bin'	# via 'dd' to CF-card

				SPECIAL_OPTIONS="$SPECIAL_OPTIONS CONFIG_TARGET_ROOTFS_JFFS2=y"
			fi
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
				'plain'|'js'|'json')
					FIRSTRUN=
				;;
				*)
					log "supported models:"
				;;
			esac

			parse_case_patterns "$funcname" | while read -r line; do {
				case "$option" in
					'plain')
						echo "$line"
					;;
					'js'|'json')
						# e.g. for 'typeahead.js'
						# see: http://intercity-vpn.de/files/typeahead-test/html/
						if [ -z "$FIRSTRUN" ]; then
							FIRSTRUN='false'
							printf '%s' "var models = ['$line'"
						else
							printf '%s' ", '$line'"
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
	# e.g. 'CONFIG_TARGET_ramips_mt7620_MIWIFI-MINI=y' -> 'ramips_mt7620'
	#
	# CONFIG_TARGET_ramips_mt7620_MIWIFI-MINI=y ->
	# CONFIG_TARGET_ramips_mt7620 ->
	#        TARGET_ramips_mt7620 ->
	#               ramips_mt7620
	ARCH="${TARGET_SYMBOL%_*}"
	ARCH="${ARCH#*_}"
	ARCH="${ARCH#*_}"
	ARCH_MAIN="${ARCH%_*}"	# ramips_mt7620 -> ramips
	ARCH_SUB="${ARCH#*_}"	# ramips_mt7620 -> mt7620
	[ "$ARCH_SUB" = "$ARCH" ] && {
		case "$FILENAME_SYSUPGRADE" in
			*'-legacy-'*)
				ARCH_SUB='legacy'	# FIXME: more generic approach
			;;
			*)
				ARCH_SUB='generic'
			;;
		esac
	}

	# 'Linksys WRT54G/GS/GL' -> 'Linksys WRT54G:GS:GL'
	HARDWARE_MODEL_FILENAME="$( echo "$HARDWARE_MODEL" | tr '/' ':' )"

	VERSION_KERNEL="$( grep ^'LINUX_VERSION:=' "target/linux/$ARCH_MAIN/Makefile" | cut -d'=' -f2 )"
	[ -n "$VERSION_KERNEL" -a -n "$VERSION_KERNEL_FORCE" ] && {
		VERSION_KERNEL="$VERSION_KERNEL_FORCE"
		file="target/linux/$ARCH_MAIN/Makefile"
		search_and_replace "$file" '^LINUX_VERSION:=.*' "LINUX_VERSION:=$VERSION_KERNEL_FORCE"
		log "enforce kernel version '$VERSION_KERNEL_FORCE', was '$VERSION_KERNEL'" gitadd "$file"
	}

	[ -z "$VERSION_KERNEL" ] && {
		# since r43047
		# KERNEL_PATCHVER:=3.10
		VERSION_KERNEL="$( grep ^'KERNEL_PATCHVER:=' "target/linux/$ARCH_MAIN/Makefile" | cut -d'=' -f2 )"
		# and in 'include/kernel-version.mk'
		# LINUX_VERSION-3.10 = .58
		VERSION_KERNEL="$( grep ^"LINUX_VERSION-$VERSION_KERNEL = " 'include/kernel-version.mk' )"
		VERSION_KERNEL="$( echo "$VERSION_KERNEL" | sed 's/ = //' | sed 's/LINUX_VERSION-//' )"

		[ -n "$VERSION_KERNEL" -a -n "$VERSION_KERNEL_FORCE" ] && {
			VERSION_KERNEL="$VERSION_KERNEL_FORCE"
			# replace in 'include/kernel-version.mk'
			# LINUX_VERSION-3.10 = .49
			# with e.g.
			# LINUX_VERSION-3.10 = .58
			# and
			# target/linux/$ARCH_MAIN/Makefile
			#   -> KERNEL_PATCHVER:=3.14
			#   -> KERNEL_PATCHVER:=3.18
			file="target/linux/$ARCH_MAIN/Makefile"
			search_and_replace "$file" '^KERNEL_PATCHVER:=.*' "KERNEL_PATCHVER:=$VERSION_KERNEL_FORCE"
			log "enforce kernel version '$VERSION_KERNEL_FORCE', was '$VERSION_KERNEL' for r43047+" gitadd "$file"
		}
	}

	log "architecture: plain/main/sub: '$ARCH'/'$ARCH_MAIN'/'$ARCH_SUB'"
	log "model: '$model' kernel: '$VERSION_KERNEL' kernel_enforced: '$VERSION_KERNEL_FORCE'"

	apply_symbol 'nuke_config'

	case "$ARCH" in
		*'_'*)
			# e.g. 'ramips_rt305x'
			apply_symbol "CONFIG_TARGET_$ARCH_MAIN=y"
		;;
		*)
			apply_symbol "CONFIG_TARGET_$ARCH=y"
		;;
	esac

	if version_is_lede ; then
		case "$FILENAME_SYSUPGRADE" in
			*'-squashfs-'*)
				# e.g. openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin
				device_symbol="${FILENAME_SYSUPGRADE#*-$ARCH_SUB-}"
				device_symbol="${device_symbol%-squashfs-*}"		# tl-wr1043nd-v1

				# e.g. 'ramips_rt305x'
				apply_symbol "CONFIG_TARGET_${ARCH}_Default is not set"
				apply_symbol "CONFIG_TARGET_${ARCH}_DEVICE_$device_symbol=y"
				apply_symbol "CONFIG_TARGET_PROFILE=\"DEVICE_$device_symbol\""
			;;
			*)
				apply_symbol "$TARGET_SYMBOL"
			;;
		esac
	else
		apply_symbol "$TARGET_SYMBOL"	# e.g. CONFIG_TARGET_ar71xx_generic_TLWR1043=y
	fi

	build 'defconfig'
}

has_internet()
{
	if   command -v route >/dev/null; then
		route -n | grep -q ^'0\.0\.0\.0'
	elif command -v ip >/dev/null; then
		ip route list exact '0.0.0.0/0' | grep -q ^'default'
	else
		log "[ERR] unsure if we have internet, allowing"
		return 0
	fi
}

feeds_prepare()
{
	local file_feeds='feeds.conf.default'
	local do_symlinking='no'
	local file githash

	grep -q 'depth 1 ' 'scripts/feeds' && {
		sed -i 's/--depth 1 /--depth 99999 /' 'scripts/feeds'
	}

	grep -Fq ' oonf '  "$file_feeds" || {
		if [ $VERSION_OPENWRT_INTEGER -ge 45668 ]; then
			# needs:
			# CMake version 2.8.12 or better
			# libnl3-dev or libnl-tiny for the nl80211-listener plugin
			# libtomcrypt-dev for the hash_tomcrypt plugin
			echo >>"$file_feeds" 'src-git-full oonf https://github.com/OLSR/OONF.git'
		else
			echo >>"$file_feeds" 'src-git      oonf https://github.com/OLSR/OONF.git'
		fi

		log "addfeed 'olsrd2/oonf'" debug,gitadd "$file_feeds"
		do_symlinking='true'
	}

	grep -F ' oldpackages ' "$file_feeds" | grep -q ^'#' && {
		# FIXME! use search_and_replace()
		# hide oldpackages
		sed >"$file_feeds.tmp" '/oldpackages/s/^#\(.*\)/\1/' "$file_feeds"
		mv   "$file_feeds.tmp" "$file_feeds"
		log "enable feed 'oldpackages'" debug,gitadd "$file_feeds"

		if has_internet; then
			# https://forum.openwrt.org/viewtopic.php?id=52219
			./scripts/feeds update oldpackages
			# install all packages from specified feed
			./scripts/feeds install -a -p oldpackages
		else
			log '[OK] no internet - only refreshing index of "oldpackages"'
			./scripts/feeds update -i oldpackages
		fi
	}

	[ -d 'package/feeds' ] || {
		# seems, everything is really untouched
		log "missing 'package/symlinks', getting feeds"
		build 'defconfig'
		do_symlinking='true'
	}

	[ "$do_symlinking" = 'true' ] && {
		# TODO: check if already done
		log "enforce/updating symlinking of packages"
		make package/symlinks
	}

	# TODO: cd feeds/routing && git stash
	file='feeds/routing/olsrd/Makefile'
	githash='2d03856'	# https://github.com/OLSR/olsrd
	if   grep -q 'PKG_VERSION:=0.9.5' "$file"; then
		:
	elif grep -q "=$githash" "$file"; then
		log "[OK] OLSRd1: Makefile already patched"
	else
		log "[OK] OLSRd1: importing Makefile" 			# gitadd,untrack "$file"
		search_and_replace "$file" '^PKG_VERSION:=.*' 'PKG_VERSION:=0.9.1'
		search_and_replace "$file" '^PKG_SOURCE_VERSION:=.*' "PKG_SOURCE_VERSION:=$githash"
		search_and_replace "$file" '.*olsrd-mod-pud))$' '# & #'	# and hide from calling
		search_and_replace "$file" ' pud ' ' '			# do not compile these plugin
		search_and_replace "$file" ' pgraph ' ' ' && {
			log "patching OLSRd1 for using recent HEAD" 	# gitadd,untrack "$file"
		}
	fi

	grep -q 'depth 99999 ' 'scripts/feeds' && {
		sed -i 's/--depth 99999 /--depth 1 /' 'scripts/feeds'
	}

	return 0
}

check_working_directory()
{
	local funcname='check_working_directory'
	local i=0
	local package list error repo git_url answer buildsystemdir pattern

	if [ -n "$FORCE" ]; then
		error=0
	else
		error=1
	fi

	[ -e 'build.sh' ] && {
		log "[OK] first run - checking dependencies"

		is_installed()
		{
			local package="$1"

			command -v dpkg 2>/dev/null >/dev/null || {
				log "$funcname -> is_installed() package '$package' -> simulating OK (no 'dpkg' found)"
				return 0
			}

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

		case "$VERSION_OPENWRT" in
			'lede-staging')
				# https://git.lede-project.org/?p=lede/nbd/staging.git;a=summary
				# https://git.lede-project.org/?a=project_list;pf=lede
				git_url='git://git.lede-project.org/lede/nbd/staging.git'
				buildsystemdir='staging'
			;;
			'lede')
				# https://git.lede-project.org/?p=source.git;a=summary
				git_url='git://git.lede-project.org/source.git'
				buildsystemdir='source'
			;;
			'lede.local')
				# idea: if next arg = existing dir, take this (so not local keyword needed)
				git_url='mylede'		# git clone git://... mylede
				buildsystemdir='source'
				VERSION_OPENWRT='lede'
			;;
			'trunk')
				# git_url='git://git.openwrt.org/openwrt.git'
				git_url='https://github.com/openwrt/openwrt'
				buildsystemdir='openwrt'
			;;
			*'.'*)
				# e.g. 14.07
				git_url="git://git.openwrt.org/$VERSION_OPENWRT/openwrt.git"
				buildsystemdir='openwrt'
			;;
		esac

		[ -d "$buildsystemdir" ] && {
			log "first start - removing (old?) dir '$buildsystemdir' - please answer Y/N"
			read -r answer

			if [ "$answer" = 'Y' ]; then
				rm -fR "$buildsystemdir"
			else
				log "[OK] leaving dir: '$buildsystemdir'"
			fi
		}

		log "first start - fetching OpenWrt/$VERSION_OPENWRT: git clone '$git_url'"
		git clone "$git_url" "$buildsystemdir" || return $error

		if [ -d "$DOWNLOAD_POOL" ]; then
			log "symlinking our central download pool '$DOWNLOAD_POOL'"
			mkdir -p "$DOWNLOAD_POOL"
			ln -s "$DOWNLOAD_POOL" "$buildsystemdir/dl"
		else
			log "[OK] no central download pool - but if you want this,"
			log "please use --download_pool '/your/absolute/path'"
		fi

		[ -d 'packages' ] && {
			log "first start - removing (old?) dir packages"
			rm -fR 'packages'
		}

		repo='git://git.openwrt.org/packages.git'
		log "first start - fetching OpenWrt-packages: git clone '$repo'"
		git clone "$repo" || return $error
		cd "$buildsystemdir" || return

		# git://github.com/weimarnetz/weimarnetz.git
		# git://github.com/bittorf/kalua.git
		repo="$KALUA_REPO_URL"
		log "first start - fetching own-repo: git clone '$repo'"
		git clone "$repo" || return $error
		KALUA_DIRNAME="$( basename "$repo" | cut -d'.' -f1 )"
		echo "$repo" >'KALUA_REPO_URL'

		log "[OK] now you should do:"
		log "debug: pwd: '$(pwd)'"
		log "cd '$buildsystemdir' && ../build.sh --help"

		exit $error
	}

	# user directory for private/overlay-files
	mkdir -p 'files'

	# for detecting: are we in "original" (aka master) tree or in private checkout
	if version_is_lede ; then
		pattern='.'	# means: any
	else
		pattern='git-svn-id'
	fi

	git log -1 | grep -q "$pattern" || {
		if git log | grep -q "$pattern"; then
			# search most recent 'good' commit
			while ! git log -$i | grep -q "$pattern"; do {
				i=$(( i + 1 ))
			} done

			log "the last commit MUST include pattern '$pattern', seems you have private"
			log "commits (when this is OK for you, just add --force to your call)."
			log "please rollback several times via: git reset --soft HEAD^"
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

feeds_adjust_version()			# needs: src git-full for the feeds and 'clone depth 9999'
{
	local timestamp="$1"		# e.g. '2009-07-27 13:37' or <empty> = HEAD/original
	local feed="$2"			# e.g. 'luci' or <empty> = all
	local dir githash oldbranch

	cd feeds || return

	for dir in *; do {
		test -d "$dir.tmp"  || continue
		test -d "$dir/.git" || continue

		[ -n "$feed" ] && {
			[ -d "$feed" ] || continue	# user want specific feed - TODO: support list
		}

		cd "$dir" || return
		if [ -n "$timestamp" ]; then
			# http://stackoverflow.com/questions/6990484/git-checkout-by-date
			# git rev-list -n 1 --before="2009-07-27 13:37" master
			githash="$( git rev-list -n 1 --before="$timestamp" master )"
		else
			githash='master'
		fi

		log "[OK] adjusting version of feed '$dir' to '$githash'"

		if   [ "$githash" = 'master' ]; then
			git branch | grep -q ^'* master' || {
				git checkout master

				for oldbranch in $( git branch | grep feeds@ | cut -b3- ); do {
					git branch -D "$oldbranch"
				} done

				../../scripts/feeds update -i "$dir"
			}
		elif [ -n "$githash" ]; then
			git checkout -b "feed@${githash}_before_$( echo "$timestamp" | tr ' ' '_' | tr ':' '-' )" "$githash"
			../../scripts/feeds update -i "$dir"
		else
			log "[OK] no commit which fits, removing feeds index of '$dir'"
			[ -e "$dir.index" ] && rm "$dir.index"
			[ -e "$dir.targetindex" ] && rm "$dir.targetindex"
		fi

		cd ..
	} done

	cd ..
}

openwrt_revision_number_get()		# e.g. 43234
{
	local rev

	if [ -d '.git' ]; then
		# works only with OpenWrt
		rev="$( git log -1 | grep 'git-svn-id' | cut -d'@' -f2 | cut -d' ' -f1 )"
	else
		# e.g. virgin script-download
		rev='UNKNOWN_REVISION'
	fi

	if [ -n "$rev" ]; then
		echo "$rev"
	else
		# is not available in all revisions or during early bootstrapping
		if [ -e 'scripts/getver.sh' ]; then
			rev="$( scripts/getver.sh )"
			case "$rev" in
				'r'[0-9]*)
					# e.g. r12345
					# e.g. r2445-ee5a6c1
					# e.g. r3128+26-64f0ef4
					echo "$rev" | cut -d'r' -f2 | cut -d'+' -f1 | cut -d'-' -f1
				;;
				*)
					echo 'UNKNOWN_REVISION'
				;;
			esac
		else
			echo 'UNKNOWN_REVISION'
		fi
	fi
}

openwrt_download()
{
	local funcname='openwrt_download'
	local wish="$1"		# <empty> = 'leave_untouched'
				# or 'r12345' or
				# or 'stable' or 'beta' or 'testing'
				# or 'trunk'
				# or 'switch_to_master'
				# or 'reset_autocommits'
	local hash branch commit
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
			wish='r47364'
		;;
	esac

	[ "$old_wish" = "$wish" ] || log "apply '$wish' (sanitized)"

	lede_fixup()
	{
		version_is_lede && {
			[ ${VERSION_OPENWRT_INTEGER:-0} -gt 0 ] && {
				VERSION_OPENWRT_INTEGER=$(( VERSION_OPENWRT_INTEGER + 1000000 ))
				VERSION_OPENWRT="r$VERSION_OPENWRT_INTEGER"
			}
		}
	}

	case "$wish" in
		'leave_untouched')
			VERSION_OPENWRT_INTEGER="$( openwrt_revision_number_get )"
			VERSION_OPENWRT="r$VERSION_OPENWRT_INTEGER"
			lede_fixup
		;;
		'trunk')
			$funcname 'switch_to_master'

			if has_internet; then
				git pull
				scripts/feeds update -a
			else
				log '[OK] no internet - only rebuilding index of all feeds'
				scripts/feeds update -i
			fi

			log "checkout local copy of trunk/$VERSION_OPENWRT"
			$funcname "$VERSION_OPENWRT"
		;;
		'r'[0-9]*)
			# e.g. r12345
			$funcname 'switch_to_master'

			# typical entry:
			# git-svn-id: svn://svn.openwrt.org/openwrt/trunk@39864 3c298f89-4303-0410-b956-a3cf2f4a3e73
			hash="$( echo "$wish" | cut -b2- )"			# r12345 -> 12345  (remove leading 'r')
			hash="$( git log --format=%h --grep="@$hash " )"	# 12345 -> fe53cab (number -> hash)

			get_lede_hash(){
				local wish="$1"		# e.g. r1492
				local line info rc

				log "get_lede_hash() input: $wish"
				wish="$( echo "$wish" | cut -b2- )"	# e.g. r1492 -> 1492

				git log --format=%h | while read -r line; do {
					git log --format=%B -n1 "$line" | grep -q '# mimic OpenWrt-style:' && {
						log "get_lede_hash() abort: found 'mimic OpenWrt-style'"
						return 1
					}

					if info="$( git describe "$line" )"; then
						# e.g. 'reboot-1492-g637640c' but empty with 'lede-staging'
						case "$info" in
							*"-$wish-"*)
								log "get_lede_hash() found $line / $info"
								echo "$line"
								return 0
							;;
						esac
					else
						log "get_lede_hash() git describe failed"
						return 1
					fi
				} done
				rc=$?	# because of subshell

				[ $rc -eq 0 ] || {
					log "get_lede_hash() no success in dir: '$( pwd )'"
					return $rc
				}
			}

			[ -z "$hash" ] && {
				hash="$( get_lede_hash "$wish" )"

				if [ -z "$hash" ]; then
					log "[ERROR] - unable to find '$wish' - using latest commit"
					# can happen if 'rXXXXX' is in packages/feeds, just use newest:
					hash="$( git log -1 --format=%h )"
				else
					log "using lede-hash: '$hash'"
				fi
			}

			# TODO: maybe write 'openwrt@hash=$revision for modelXY'?
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

			VERSION_OPENWRT="$wish"			# e.g. r12345
			VERSION_OPENWRT_INTEGER="${wish#*r}"	# e.g.  12345
			lede_fixup
		;;
		'reset_autocommits')
			found_autocommit()
			{
				# from log/gitadd
				git log HEAD...HEAD^^ | grep -Fq '# mimic OpenWrt-style:'
			}

			while found_autocommit; do {
				commit="$( git log HEAD...HEAD^^ | grep ^'commit ' | tail -n1 | cut -d' ' -f2 )"
				git reset --hard $commit
			} done
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

			VERSION_OPENWRT_INTEGER="$( openwrt_revision_number_get )"
			VERSION_OPENWRT="r$VERSION_OPENWRT_INTEGER"
			lede_fixup

			git stash list | grep -qv '() going to checkout ' && {
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

usecase_has()
{
	local usecase_keyword="$1"	# e.g. 'noDebug'
	local oldIFS="$IFS"; IFS=','; set -- $LIST_USER_OPTIONS; IFS="$oldIFS"

	case " $* " in
		" $usecase_keyword ")
			return 0
		;;
		*)
			return 1
		;;
	esac
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
	} done | LC_ALL=C sort | md5sum | cut -d' ' -f1
}

copy_firmware_files()
{
	local funcname='copy_firmware_files'
	local attic="bin/$ARCH_MAIN/attic"
	local file file_size checksum_md5 checksum_sha256 rootfs server_dir server
	local destination destination_scpsafe destination_info destination_info_scpsafe pre
	local usign_bin usign_pubkey usign_privkey usign_signature myhash
	local err=0

	mkdir -p "$attic"
	rootfs='squash'

	version_is_lede && {
		# bin/targets/ramips/mt7621/lede-ramips-mt7621-witi-squashfs-sysupgrade.bin
		FILENAME_FACTORY="$(    echo "$FILENAME_FACTORY"    | sed 's/openwrt/lede/g' )"
		FILENAME_SYSUPGRADE="$( echo "$FILENAME_SYSUPGRADE" | sed 's/openwrt/lede/g' )"
	}

	# change image-filesnames for some TP-Link routers: https://dev.openwrt.org/changeset/48767
	[ $VERSION_OPENWRT_INTEGER -ge 48767 ] && {
		case "$FILENAME_FACTORY" in
			*'wr'[0-9][0-9][0-9]'nd-v'*|*'wr'[0-9][0-9][0-9]'n-v'*)
				log "[OK] fixup filename '$FILENAME_FACTORY'"
				log "[OK] fixup filename '$FILENAME_SYSUPGRADE'"

				# ...-tl-wr841nd-v7-... -> ...-tl-wr841-v7-...
				FILENAME_FACTORY="$(    echo "$FILENAME_FACTORY"    | sed 's/\(^.*[0-9]\)nd\(-.*\)/\1\2/' )"
				FILENAME_SYSUPGRADE="$( echo "$FILENAME_SYSUPGRADE" | sed 's/\(^.*[0-9]\)nd\(-.*\)/\1\2/' )"
			;;
		esac
	}

	# Ubiquiti Bullet M
	destination="$HARDWARE_MODEL_FILENAME"

	if version_is_lede ; then
		pre="bin/targets/$ARCH_MAIN/$ARCH_SUB"

		# special: see lede_fixup()
		# Ubiquiti Bullet M.openwrt=r38576
		destination="${destination}.lede=r$(( VERSION_OPENWRT_INTEGER - 1000000 ))"
	else
		pre="bin/$ARCH_MAIN"

		# Ubiquiti Bullet M.openwrt=r38576
		destination="${destination}.openwrt=${VERSION_OPENWRT}"
	fi

	# workaround: when build without kalua
	[ -z "$USECASE_DOWNLOAD" ] && USECASE_DOWNLOAD="$USECASE"

	myhash="$( usecase_hash "$USECASE_DOWNLOAD" )"
	log "openwrt-version: '$VERSION_OPENWRT' with kernel: '$VERSION_KERNEL' for arch/main/sub '$ARCH'/'$ARCH_MAIN'/'$ARCH_SUB'"
	log "hardware: '$HARDWARE_MODEL'"
	log "usecase: --usecase $USECASE"
	log "usecase-hash: $myhash"

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
	destination="${destination}_option=${USECASE}"

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
		file="$pre/$FILENAME_FACTORY"
		log "$( wc -c <"$file" ) Bytes: '$FILENAME_FACTORY'"
	else
		file="$pre/$FILENAME_SYSUPGRADE"
		log "$( wc -c <"$file" ) Bytes: '$FILENAME_SYSUPGRADE'"
	fi


	if [ -e "$file" ]; then
		cp -v "$file" "$attic/$destination"
	else
		err=1
	fi

	# real file:
	# /var/www/networks/liszt28/firmware/models/TP-LINK+TL-WR1043ND/testing/Standard,kalua/...fullname...
	#
	# for firmware-downloader: (only symlink)
	# /var/www/networks/liszt28/firmware/models/TP-LINK+TL-WR1043ND/testing/.49c4b5bf00fd398fba251a59f628de60.bin

	[ -n "$RELEASE" -a -e "$file" ] && {
		checksum_md5="$( md5sum "$file" | cut -d' ' -f1 )"
		checksum_sha256="$( sha256sum "$file" | cut -d' ' -f1 )"
		file_size="$( wc -c <"$file" )"

		usign_bin='./staging_dir/host/bin/usign'
		[ -e "$usign_bin" ] && {
			usign_privkey='../build.privkey'
			usign_pubkey='../build.pubkey'

			[ -e "$usign_privkey" -o -e "$usign_pubkey" ] || {
				$usign_bin -G -p "$usign_pubkey" -s "$usign_privkey"
			}

			usign_signature="$( $usign_bin -S -m "$file" -s "$usign_privkey" -x - | grep -v ^'untrusted comment' )"
		}

		# TODO: keep factory + sysupgrade in sync
		# TODO: nice browsing like 'https://weimarnetz.de/freifunk/firmware/nightlies/ar71xx/'
		# TODO: json: use integers where applicable?
		#
		# autoupdate-scheme: there is a changed image
		# - a running node compares it's own revision, with revision on server
		# - changed revision = upgrade, so also auto-downgrading is possible
		# - revision also for showing in a dialog/GUI
		cat >'info.json' <<EOF
{
  "build_host": "$( hostname )",
  "build_time": "$( date )",
  "build_duration_sec": "$BUILD_DURATION",
  "firmware_file": "$destination",
  "firmware_size": "$file_size",
  "firmware_md5": "$checksum_md5",
  "firmware_sha256": "$checksum_sha256",
  "firmware_signature": "$usign_signature",
  "firmware_kernel": "$VERSION_KERNEL",
  "firmware_rev": "$VERSION_OPENWRT_INTEGER",
  "firmware_usecase": "$USECASE_DOWNLOAD",
  "firmware_usecase_hash": "$myhash"
}
EOF
		# root@intercity-vpn.de:/var/www/networks/liszt28 -> root@intercity-vpn.de
		server="${RELEASE_SERVER%:*}"
		# root@intercity-vpn.de:/var/www/networks/liszt28 -> /var/www/networks/liszt28
		server_dir="${RELEASE_SERVER#*:}/firmware/models/$HARDWARE_MODEL_FILENAME/$RELEASE/$USECASE_DOWNLOAD"
		#
		destination="$server_dir/$destination"		# full filename
		destination_info="$server_dir"

		scripts/diffconfig.sh >'info.diffconfig.txt'
		[ -d 'logs' ] && tar cJf 'info.buildlog.tar.xz' logs/

		scp_safe()
		{
			# each space needs 2 slashes: 'a b' -> 'a\\ b'
			echo "$1" | sed 's| |\\\\ |g'
		}

		# workaround with sourcing file is needed, because
		# directly using the vars leads do 'scp: ambiguous target'
		cat >./DO_SCP.sh <<EOF
#!/bin/sh

upload()
{
	ssh $server "mkdir -p '$server_dir' && cd '$server_dir' && rm -f *" || return 1

	scp "$file"     $server:"$( scp_safe "$destination" )"		|| return 2
	scp 'info.'*    $server:"$( scp_safe "$destination_info/" )"	|| return 3

	# in front of 'usercase_hash' is a 'dot' (so hidden when browsing)
	ssh $server    "cd '$server_dir' && cd .. && \
			mkdir -p '.$myhash' && cd '.$myhash' && \
				ln -sf '$destination' '$HARDWARE_MODEL_FILENAME.bin' || return 4
				ln -sf '$destination_info/info.json' 'info.json'" || return 5
}

upload || {
	log "upload-error: $?"
	err=1
}
EOF
		. ./DO_SCP.sh
		[ $err -eq 0 ] && {
			rm ./DO_SCP.sh 'info.'*
			log "[OK] upload ready, see: server: $server destination: $destination_info"
		}
	}

	return $err
}

calc_time_diff()
{
	local t1="$1"		# e.g. read -r t1 rest </proc/uptime
	local t2="$2"
	local duration

	duration=$(( ${t2%.*}${t2#*.} - ${t1%.*}${t1#*.} ))
	duration=$(( duration / 100 )).$(( duration % 100 ))

	echo "$duration"
}

get_uptime_in_sec()
{
	local varname="$1"
	local field1 rest

	# e.g. 38409.14
	read -r field1 rest 2>/dev/null </proc/uptime || field1='1.00'

	eval $varname=$field1
}

cpu_count()
{
	if   grep -sc ^'processor' '/proc/cpuinfo'; then
		:
	elif command -v lsconf 2>/dev/null >/dev/null; then
		# e.g. AIX - see http://antmeetspenguin.blogspot.de/2013/05/aix-cpu-info.html
		lsconf | grep -c 'proc[0-9]'
	else
		echo '1'
	fi
}

cpu_load_integer()
{
	local funcname='cpu_load_integer'

	# AIX-7 / gcc111
	#  12:16AM   up 121 days,  12:34,  3 users,  load average: 3.75, 4.00, 4.42
	# LINUX:
	# 09:18:12 up 12 min,  load average: 0.54, 0.85, 0.58
	set -- $( uptime )

	while [ -n "$1" ]; do {
		case "$1" in
			'average:')
				local loadavg="$2"

				loadavg="${loadavg%.*}${loadavg#*.}"	# 3.75, -> 375
				loadavg="${loadavg%,*}"			# 375, -> 375
				loadavg="${loadavg#0}"
				loadavg="${loadavg#0}"			# 005 -> 5

				[ $loadavg -ge 100 ] && \
					log "high load: $2 -> $loadavg (affects number of make-threads -> build-speed)"

				echo "$loadavg"
				break
			;;
		esac

		shift
	} done
}

build()
{
	local funcname='build'
	local option="$1"
	local make_verbose t1 t2 buildjobs commandline

	[ -n "$DEBUG" ] && make_verbose='V=s'

	buildjobs=$(( $( cpu_count ) + 1 ))
	# do not stress if we already have load / e.g. gcc-farm
	[ $CPU_LOAD_INTEGER -ge 100 ] && buildjobs=$(( (buildjobs - 1) / 2 ))
	[ -d 'logs' ] && rm -fR 'logs'
	commandline="--jobs $buildjobs BUILD_LOG=1"

	case "$option" in
		'nuke_bindir')
			log "$option: removing unneeded firmware/packages, but leaving 'attic'-dir"
			rm     "bin/$ARCH_MAIN/"*	 2>/dev/null
			rm -fR "bin/$ARCH_MAIN/packages" 2>/dev/null
		;;
		'defconfig')
			log "running 'make defconfig'" debug
			[ -f '.config' ] && [ -n "$DEBUG" -a $( wc -l <'.config' ) -lt 10 ] && cat '.config'
			log "end of .config" debug

			get_uptime_in_sec 't1'
			make $make_verbose defconfig >/dev/null || make defconfig
			get_uptime_in_sec 't2'
			log "running 'make $option' needed $( calc_time_diff "$t1" "$t2" ) sec"
		;;
		*)
			[ -n "$MAC80211_CLEAN" ] && {
				log "running 'make package/kernel/mac80211/clean'"
				make package/kernel/mac80211/clean
			}

			log "running 'make $commandline'"
			get_uptime_in_sec 't1'

			if make $make_verbose $commandline ; then
				get_uptime_in_sec 't2'
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
				log "do: 'find logs -type f -exec stat -c '%y %N' {} \; | sort -n'"
				log "first build unparallel with: 'make -j1 BUILD_LOG=1'"
				log "initial call was: $ARGUMENTS_MAIN"
				return 1
			fi
		;;
	esac
}

apply_patches()
{
	local file

	log "$KALUA_DIRNAME: tweaking kernel commandline"
	kernel_commandline_tweak

	if usecase_has 'noReghack' ; then
		log "$KALUA_DIRNAME: disable Reghack"
		apply_wifi_reghack 'disable'
	else
		log "$KALUA_DIRNAME: apply_wifi_reghack"
		apply_wifi_reghack
	fi

	list_files_and_dirs()
	{
		local folder dir file

		# /dir/file1
		# /dir/file2
		# /dir/dirX/file1 ...
		for folder in "$KALUA_DIRNAME/openwrt-patches/add2trunk" $PATCHDIR; do {
			find $folder -type d | while read -r dir; do {
				echo "$dir"
				find "$dir" -maxdepth 1 -type f | sort
			} done
		} done
	}

	list_files_and_dirs | while read -r file; do {
		case "$file" in
			*'-ath10k-'*)
				grep -q '_kmod-ath10k' '.config' || {
					log "[OK] ignoring patch: $file"
					continue
				}
			;;
		esac

		if [ -d "$file" ]; then
			log "dir: $file" debug
			register_patch "DIR: $file"
		else
			patch_for_openwrt()
			{
				grep -q ^'To: openwrt-devel@lists.openwrt.org' "$1" && return 0
				grep -q ' a/package/' "$1" && return 0
				grep -q ' a/include/' "$1"
			}

			patch_for_mac80211()
			{
				grep -q ' a/include/net/mac80211.h' "$1" && return 0
				grep -q ' a/net/mac80211/' "$1"
			}

			patch_for_atheros_driver()
			{
				grep -q ' a/drivers/net/wireless/ath/' "$1" && return 0
				grep -q ' a/net/wireless/ath/' "$1"
			}

			patch_for_busybox()
			{
				patch_for_openwrt "$1" && return 1
				grep -q 'bb_error_msg_and_die' "$1"
			}

			patch_for_kernel()
			{
				# FIXME!
				grep -q ' a/net/sched/' "$1"
			}

			patch_for_dropbear()
			{
				grep -q ' a/svr-auth.c' "$1"
			}

			patch_for_fstools()
			{
				grep -q ' a/libfstools/' "$1"
			}

			patch_for_musl()
			{
				case "$1" in
					*'-musl-'*)
					;;
					*)
						return 1
					;;
				esac
			}

			if   patch_for_mac80211 "$file"; then
				register_patch "$file"
				cp -v "$file" 'package/kernel/mac80211/patches'
				log "mac80211.generic: adding '$file'" gitadd "package/kernel/mac80211/patches/$( basename "$file" )"
				MAC80211_CLEAN='true'
			elif patch_for_atheros_driver "$file"; then
				register_patch "$file"
				cp -v "$file" 'package/kernel/mac80211/patches'
				log "mac80211.atheros: adding '$file'" gitadd "package/kernel/mac80211/patches/$( basename "$file" )"
				MAC80211_CLEAN='true'
			elif patch_for_busybox "$file"; then
				register_patch "$file"
				cp -v "$file" 'package/utils/busybox/patches'
				log "busybox: adding '$file'" gitadd "package/utils/busybox/patches/$( basename "$file" )"
			elif patch_for_kernel "$file"; then
				log "[FIXME] ignoring '$file'"
			elif patch_for_dropbear "$file"; then
				register_patch "$file"
				cp -v "$file" 'package/network/services/dropbear/patches'
				log "dropbear: adding '$file'" gitadd "package/network/services/dropbear/patches/$( basename "$file" )"
			elif patch_for_fstools "$file"; then
				register_patch "$file"
				mkdir -p 'package/system/fstools/patches'
				cp -v "$file" 'package/system/fstools/patches'
				log "fstools: adding '$file'" gitadd "package/system/fstools/patches/$( basename "$file" )"
			elif patch_for_musl "$file"; then
				register_patch "$file"
				mkdir -p 'toolchain/musl/patches'
				cp -v "$file" 'toolchain/musl/patches'
				log "musl: adding '$file'" gitadd "toolchain/musl/patches/$( basename "$file" )"
			elif patch_for_openwrt "$file"; then
				if git apply --ignore-whitespace --check <"$file"; then
					# http://stackoverflow.com/questions/15934101/applying-a-diff-file-with-git
					# http://stackoverflow.com/questions/3921409/how-to-know-if-there-is-a-git-rebase-in-progress
					[ -d '.git/rebase-merge' -o -d '.git/rebase-apply' ] && {
						git rebase --abort
						git am --abort
					}

					# FIXME!
					# automatically add 'From:' if missing
					# sed '1{s/^/From: name@domain.com (Proper Name)\n/}'

					if git am --ignore-whitespace --signoff <"$file"; then
						log "[OK] patched ontop OpenWrt: '$file'" debug
						register_patch "$file"
					else
						git am --abort
						log "[ERROR] during 'git am <$file'"
					fi
				else
					register_patch "FAILED: $file"
					log "$KALUA_DIRNAME: [ERROR] cannot apply: git apply --check <'$file'"
				fi
			else
				log "[ERROR] do not know, where to apply: '$file'"
			fi
		fi
	} done
}

apply_kernelsymbol()
{
	local funcname='apply_kernelsymbol'
	local symbol="$1"
	local file="$( kconfig_file )"

	log "$funcname -> $symbol -> $file"
}

apply_symbol()
{
	local funcname='apply_symbol'
	local symbol="$1"
	local symbol_kernel="$2"
	local file='.config'
	local custom_dir='files'	# standard way to add/customize
	local hash tarball_hash rev commit_info
	local last_commit_unixtime last_commit_date url
	local file file_original installation sub_profile node
	local dir pre size1 size2 gain firstline symbol_temp

	case "$symbol" in
		'now')
			build 'defconfig'
			return $?
		;;
		"$KALUA_DIRNAME"*)
			log "$KALUA_DIRNAME: getting files"

			# is a short hash, e.g. 'ed0e11ci', this is enough:
			# http://lkml.indiana.edu/hypermail/linux/kernel/1309.3/04147.html
			cd $KALUA_DIRNAME || return
			VERSION_KALUA="$( git log -1 --format=%h )"
			last_commit_unixtime="$( git log -1 --pretty=format:%ct )"
			last_commit_unixtime_in_hours=$(( last_commit_unixtime / 3600 ))
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

			USECASE_DOWNLOAD="${USECASE}${USECASE+,}$KALUA_DIRNAME"
			USECASE="${USECASE_DOWNLOAD}@$VERSION_KALUA"

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
			cd $KALUA_DIRNAME || return
			find openwrt-addons/* -type f | while read -r file_original; do {
				case "$file_original" in
					*'admin.html')
					;;
					*)
						[ "$( mimetype_get "$file_original" )" = 'text/x-shellscript' ] || {
							log "$KALUA_DIRNAME: ignoring file: '$file_original'"
							continue
						}
					;;
				esac

				file="$( basename "$file_original" )"
				dir="../$custom_dir/$( dirname $file_original | sed "s|openwrt-addons/||" )"
				mkdir -p $dir
				firstline="$( head -n1 "$file_original" )"
				commit_info="$( git log -1 --pretty='format:%aD | commit: %h' -- "$file_original" )"

				{
					# TODO: http://www.stack.nl/~dimitri/doxygen/manual/docblocks.html#specialblock
					# TODO: add function-table with args + help on top
					echo "$firstline"
					echo "# this file belongs to $KALUA_DIRNAME: $KALUA_REPO_URL"
					echo "# last change: $commit_info | $file_original"
					echo
					tail -n +2 "$file_original"
				} >"$dir/$file"

				chmod +x "$dir/$file"
			} done
			cd - >/dev/null || return

			log "$KALUA_DIRNAME: adding 'apply_profile' stuff to '$custom_dir/etc/init.d/'"
			cp "$KALUA_DIRNAME/openwrt-build/apply_profile"* "$custom_dir/etc/init.d"

			# FIXME: do not touch rc.local
			log "$KALUA_DIRNAME: adding initial rc.local"
			echo  >'package/base-files/files/etc/rc.local' '#!/bin/sh'
			echo >>'package/base-files/files/etc/rc.local' "[ -e '/tmp/loader' ] || /etc/init.d/cron.user boot"
			echo >>'package/base-files/files/etc/rc.local' 'exit 0'
			log "own rc.local" gitadd "package/base-files/files/etc/rc.local"

			log "$KALUA_DIRNAME: adding version-information = '$last_commit_date'"
			{
				echo "FFF_PLUS_VERSION=$last_commit_unixtime_in_hours	# $last_commit_date"
				echo "FFF_VERSION=2.0.0			# OpenWrt based / unused"
			} >"$custom_dir/etc/variables_fff+"

			log "$KALUA_DIRNAME: adding hardware-model to 'files/etc/HARDWARE'"
			echo >"$custom_dir/etc/HARDWARE" "$HARDWARE_MODEL"

			log "[OK] added custom dir" gitadd "$custom_dir"

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

			# FIXME! do not hardcode testnet
			# FIXME! in --release mode, take values from cmdline
			url='http://intercity-vpn.de/networks/liszt28/tarball/testing/info.txt'

			log "$KALUA_DIRNAME: adding recent tarball hash from '$url'"
			tarball_hash="$( wget -qO - "$url" | grep -F 'tarball.tgz' | cut -d' ' -f2 )"
			if [ -z "$tarball_hash" ]; then
				log "[ERR] cannot fetch tarball hash from '$url'"
				log "[ERR] be prepared that your node will automatically perform an update upon first boot"
			else
				echo >'files/etc/tarball_last_applied_hash' "$tarball_hash"
				log "added tarball hash" gitadd 'files/etc/tarball_last_applied_hash'
			fi

			if [ -e '/tmp/apply_profile.code.definitions' ]; then
				file="$custom_dir/etc/init.d/apply_profile.code.definitions.private"
				cp '/tmp/apply_profile.code.definitions' "$file"
				log "$KALUA_DIRNAME: using custom '/tmp/apply_profile.code.definitions'" gitadd "$file"
			else
				[ -e "$custom_dir/etc/init.d/apply_profile.code.definitions.private" ] && rm "$custom_dir/etc/init.d/apply_profile.code.definitions.private"
				log "$KALUA_DIRNAME: no '/tmp/apply_profile.code.definitions' found, using standard $KALUA_DIRNAME file"
			fi

			[ -n "$CONFIG_PROFILE" ] && {
				file="$custom_dir/etc/init.d/apply_profile.code"
				installation="$( echo "$CONFIG_PROFILE" | cut -d'.' -f1 )"
				sub_profile="$(  echo "$CONFIG_PROFILE" | cut -d'.' -f2 )"
				node="$(         echo "$CONFIG_PROFILE" | cut -d'.' -f3 )"

				search_and_replace "$file" '^#SIM_ARG1=' "SIM_ARG1=$installation    #"
				search_and_replace "$file" '^#SIM_ARG2=' "SIM_ARG2=$sub_profile    #"
				search_and_replace "$file" '^#SIM_ARG3=' "SIM_ARG3=$node    #"
				search_and_replace "$file" "^#\[ \"\$SIM_ARG3' '\[ \"\$SIM_ARG3"	# wan-dhcp for node 2

				chmod +x "$file"
				log "$KALUA_DIRNAME: enforced profile: $installation - $sub_profile - $node" gitadd "$file"
			}

			log "adding patchlist" gitadd "$custom_dir/etc/openwrt_patches"

			[ -n "$hash" ] && {
				cd $KALUA_DIRNAME || return
				git checkout master
				git branch -D "$KALUA_DIRNAME@$hash"
				cd ..
			}

			set -- $( du -s "$custom_dir" )
			size1="$1"
			tar cJf "$custom_dir.tar.xz" "$custom_dir"
			set -- $( du -s "$custom_dir.tar.xz" && rm "$custom_dir.tar.xz" )
			size2="$1"
			gain=$(( size2 * 100 / size1 ))
			log "[OK] custom dir '$custom_dir' adds $size1 kilobytes (~${size2}k = ${gain}% xz-compressed) to your image"

			return 0
		;;
		'nuke_customdir')
			log "removing dir for custom files: '$custom_dir/'"
			rm -fR "$custom_dir"
			mkdir  "$custom_dir"

			return 0
		;;
		'kernel')
			# TODO: is 'kconfig_file() and apply_kernelsymbol()' needed?
			# apply_symbol kernel 'CONFIG_PRINTK is not set' -> 'CONFIG_KERNEL_PRINTK is not set'
			log "working on kernel-symbol '$symbol_kernel' -> '$( echo "$symbol_kernel" | sed 's/CONFIG_/CONFIG_KERNEL_/' )'"
			apply_symbol "$( echo "$symbol_kernel" | sed 's/CONFIG_/CONFIG_KERNEL_/' )"
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
		'kernel')
			symbol="$symbol_kernel"
		;;
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
				log "enabling BUSYBOX_CUSTOM in preparation of '$symbol'"
				echo 'CONFIG_BUSYBOX_CUSTOM=y' >>"$file"
			}
		;;
	esac

	case "$symbol" in
		'CONFIG_KERNEL_'*)
			file="$( kconfig_file )"
			if [ -e "$file" ]; then
				log "kernel-symbol: '$symbol' to '$file'"
			else
				log "kernel-symbol: '$symbol' - file missing: '$file'"
				return 1
			fi
		;;
	esac

	case "$symbol" in
		*'=y')
			symbol_temp="$symbol"
			symbol="$( echo "$symbol" | cut -d'=' -f1 )"

			if grep -sq ^"# $symbol is not set" "$file"; then
				search_and_replace "$file" "^# $symbol is not set" "$symbol=y"
			else
				grep -sq ^"$symbol=y"$ "$file" || echo >>"$file" "$symbol=y"
			fi

			symbol="$symbol_temp"	# for later logging
		;;
		*' is not set')
			symbol_temp="$symbol"
			set -- $symbol
			symbol="$1"

			if grep -sq ^"$symbol=y" "$file"; then
				search_and_replace "$file" "^$symbol=y" "# $symbol is not set"
			else
				grep -sq "$symbol" "$file" || echo >>"$file" "# $*"
			fi

			symbol="$symbol_temp"	# for later logging
		;;
		'CONFIG_'*)
			# e.g. CONFIG_B43_FW_SQUASH_PHYTYPES="G"
			# e.g. CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=64
			log "CONFIG_-mode => '$symbol'" debug

			# not in config with needed value?
			grep -sq ^"$symbol"$ "$file" || {
				pre="$( echo "$symbol" | cut -d'=' -f1 )"	# without '=64' or '="G"'

				# if already config, but with another value?
				if grep -q ^"$pre=" "$file"; then
					log "replacing value of '$pre', was: '$symbol'"

					grep -v ^"$pre=" "$file" >"$file.tmp"	# exclude line
					echo "$symbol" >>"$file.tmp"		# write symbol
					mv   "$file.tmp" "$file"		# ready
				else
					echo "$symbol" >>"$file"
				fi
			}
		;;
	esac

	case "$symbol" in
		'CONFIG_KERNEL_'*)
			log "[OK] kconfig-symbol: $symbol" gitadd "$file"
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
	local options="$1"	# <usecase> FIXME! support 'xy is not set' (spaces!)
	local subcall="$2"	# <usecase> or 'hide'
	local file='.config'
	local custom_dir='files'
	local kmod

	case "$options" in
		'ready')	# parser_ignore
			[ -e '../build.pubkey' ] && {			# parser_ignore
				cp '../build.pubkey' "$custom_dir/etc/kalua.usign_pubkey"
				log "adding usign pubkey" gitadd "$custom_dir/etc/kalua.usign_pubkey"
			}						# parser_ignore

			file="$custom_dir/etc/openwrt_build"
			grep -v ^'patch:' "${file}.details" >>"$file"

			# see autocommit()
			grep -q ^'patch:' "${file}.details" && {	# parser_ignore
				{
					echo
					echo 'patches:'
					grep ^'patch:' "${file}.details"
				} >>"$file"
			}						# parser_ignore

			rm -f "${file}.details"
			log "remove tempfile" debug,gitadd "${file}.details"

			log "[OK] writing details" gitadd "$file"
			return 0
		;;
	esac

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
			"-$KALUA_DIRNAME"*)	# parser_ignore
						# direct call to kalua (no subcall)
			;;
			*'=y'|*[.0-9])		# parser_ignore
						# e.g. CONFIG_TARGET_ROOTFS_INITRAMFS=y
						# e.g. SQUASHFS_BLOCK_SIZE=64
			;;
			'-'*)	# parser_ignore
				# direct call (no subcall)
				[ "$subcall" = 'hide' ] || USECASE="${USECASE}${USECASE+,}${1}"
			;;
		esac

		case "$1" in
			'CONFIG_'*)	# parser_ignore
				apply_symbol "$1"

				# FIXME! remove if parsing '$SPECIAL_OPTIONS' with spaces it fixed
				case "$1" in
					'CONFIG_TARGET_ROOTFS_PARTSIZE='*)	# parser_ignore
						apply_symbol 'CONFIG_TARGET_IMAGES_GZIP is not set'
					;;
				esac
			;;
			'defconfig')	# parser_ignore
					# this simply adds or deletes no symbols
			;;
			"$KALUA_DIRNAME")
				apply_symbol "$1"
			;;
			"$KALUA_DIRNAME@"*)	# parser_ignore
				apply_symbol "$1"
			;;
			'OpenWrt')
				# we do nothing and rely on defconfig
			;;
			'noReghack')
				# we work on this during above $KALUA_DIRNAME
			;;
			'MinstrelRhapsody')
				apply_minstrel_rhapsody
				apply_symbol 'CONFIG_PACKAGE_MAC80211_RC_RHAPSODY_BLUES=y'
			;;
			'zRAM')
				grep -q 'CONFIG_PACKAGE_fstools=y' "$file" || {
					apply_symbol 'CONFIG_BUSYBOX_CONFIG_SWAPONOFF=y'
					apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_SWAPON_PRI=y'
				}	# parser_ignore

				apply_symbol 'CONFIG_PACKAGE_zram-swap=y'		# base-system: zram-swap

# https://dev.openwrt.org/ticket/19586
#				apply_symbol 'CONFIG_PROCD_ZRAM_TMPFS=y'		# since r43489
#				apply_symbol 'CONFIG_PACKAGE_kmod-fs-ext4=y'		# needed for compressed ramdisc
#				apply_symbol 'CONFIG_PACKAGE_e2fsprogs=y'		# dito | utilities: filesystem:
			;;
			'musl')
				usecase_has 'uclibc' || {
					apply_symbol 'CONFIG_DEVEL=y'
					apply_symbol 'CONFIG_TOOLCHAINOPTS=y'
					apply_symbol 'CONFIG_LIBC_USE_MUSL=y'
				}	# parser_ignore
			;;
			'uclibc')
				# removed with r47357/r47401
				usecase_has 'musl' || {
					apply_symbol 'CONFIG_DEVEL=y'
					apply_symbol 'CONFIG_TOOLCHAINOPTS=y'
					apply_symbol 'CONFIG_LIBC_USE_UCLIBC=y'

					apply_symbol 'CONFIG_PKG_CHECK_FORMAT_SECURITY is not set'
					apply_symbol 'CONFIG_KERNEL_CC_STACKPROTECTOR_NONE=y'		# unneeded?
					apply_symbol 'CONFIG_PKG_FORTIFY_SOURCE_NONE=y'			# unneeded?
					apply_symbol 'CONFIG_PKG_RELRO_NONE=y'				# unneeded?
					apply_symbol 'CONFIG_SSP_SUPPORT is not set'
				}	# parser_ignore
			;;
			'Standard')	# >4mb flash
				apply_symbol 'CONFIG_DROPBEAR_CURVE25519=y'		# default since r48196 -> adds 40k
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_kmod-ipt-raw=y'
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-conntrack-extra=y'	# +100k?
				apply_symbol 'CONFIG_PACKAGE_resolveip=y'		# base-system: +3k
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g
				apply_symbol 'CONFIG_PACKAGE_rrdtool1=y'		# utilities: rrdtool:
				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless:
#				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools (=iwconfig)
				#
# since r48386 is 'uclient'	apply_symbol 'CONFIG_PACKAGE_curl=y'			# network: file-transfer: curl
				apply_symbol 'CONFIG_PROCD_SHOW_BOOT=y'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_TRACEROUTE6=y'	# +1k
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_TELNET=y'		# client (remote if all are at CC15.5+)

				apply_symbol 'kernel' 'CONFIG_SQUASHFS_EMBEDDED=y'	# https://www.kernel.org/doc/menuconfig/fs-squashfs-Kconfig.html
				apply_symbol 'kernel' 'CONFIG_SQUASHFS_FRAGMENT_CACHE_SIZE=1'

				$funcname subcall 'iproute2'
				$funcname subcall 'squash64'
				$funcname subcall 'zRAM'
				$funcname subcall 'netcatFull'
				$funcname subcall 'shaping'
				$funcname subcall 'vtun'
				$funcname subcall 'mesh'
				$funcname subcall 'noFW'

#				[ "$ARCH" = 'ar71xx' ] && {
#					$funcname subcall 'revert46432'		# FIXME! keep kernel 3.18.19 for ar71xx
#					$funcname subcall 'revert46553'		# dito
#				}	# parser_ignore

				usecase_has 'noDebug' || {
					log "[OK] autoselecting usecase 'debug' in 'Standard'-mode"
					$funcname subcall 'debug'
				}	# parser_ignore

				grep -q 'CONFIG_USB_SUPPORT=y' "$file" && {
					log "[OK] autoselecting usecase 'USBstorage' in 'Standard'-mode"
					$funcname subcall 'USBstorage'
				}	# parser_ignore
			;;
			'Small')	# <4mb flash - for a working jffs2 it should not exceed '3.670.020' bytes (e.g. WR703N)
				apply_symbol 'CONFIG_DROPBEAR_CURVE25519 is not set'	# default since r48196 -> saves 40k
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_kmod-ipt-raw=y'
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
#				apply_symbol 'CONFIG_PACKAGE_iptables-mod-conntrack-extra=y'	# +100k?
				apply_symbol 'CONFIG_PACKAGE_resolveip=y'		# base-system: +3k
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
#				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
#				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g +9k
#				apply_symbol 'CONFIG_PACKAGE_rrdtool1=y'		# utilities: rrdtool:
#				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless: (but debugFS-export still active)
#				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
#				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools
				apply_symbol 'CONFIG_ATH9K_UBNTHSR is not set'
#				apply_symbol 'CONFIG_PACKAGE_curl=y'
#				apply_symbol 'CONFIG_PROCD_SHOW_BOOT=y'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_TRACEROUTE6=y'	# +1k
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_TELNET=y'		# client (remote if all are at CC15.5+)

				apply_symbol 'kernel' 'CONFIG_SQUASHFS_EMBEDDED=y'	# https://www.kernel.org/doc/menuconfig/fs-squashfs-Kconfig.html
				apply_symbol 'kernel' 'CONFIG_SQUASHFS_FRAGMENT_CACHE_SIZE=1'

				$funcname subcall 'iproute2'
#				$funcname subcall 'squash64'
				$funcname subcall 'zRAM'
				$funcname subcall 'netcatFull'
#				$funcname subcall 'shaping'
#				$funcname subcall 'vtun'
#				$funcname subcall 'mesh'
				$funcname subcall 'noFW'

#				[ "$ARCH" = 'ar71xx' ] && {
#					$funcname subcall 'revert46432'		# FIXME! keep kernel 3.18.19
#					$funcname subcall 'revert46553'		# dito
#				}	# parser_ignore
			;;
			'Mini')
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# kernel-modules: wireless:

				$funcname subcall 'noFW'
				$funcname subcall 'noPPPoE'
				$funcname subcall 'noHTTPd'
				$funcname subcall 'noWIFI'
				$funcname subcall 'noSSH'
				$funcname subcall 'noOPKG'
				$funcname subcall 'noPPPoE'
				$funcname subcall 'noDebug'
				$funcname subcall 'noSWAP'
				$funcname subcall 'noIPv6'	# (only works together without iptables)
				# TODO: noIPtables (works only together
			;;
			'Micro')
				# TODO!
				# like mini and: noWiFi, noDNSmasq, noJFFS2-support?
				# remove 'mtd' (~15k) if device can be flashed via bootloader?
			;;
			'freifunk')
				$funcname subcall 'Standard'
				$funcname subcall 'OWM'
				$funcname subcall 'LuCIfull'
			;;
			'freifunk-4mb')
				$funcname subcall 'Small'
				$funcname subcall 'noOPKG'
				$funcname subcall 'noPPPoE'
				$funcname subcall 'noDebug'
				$funcname subcall 'OLSRd'
				$funcname subcall 'OWM'
				$funcname subcall 'LuCI'
			;;
			'freifunk-2mb')
				# TODO
			;;
			### here starts all functions/packages, above are 'meta'-descriptions ###
			'debug')
				apply_symbol 'CONFIG_USE_STRIP=y'			# Global build settings: Binary stripping method
				apply_symbol 'CONFIG_USE_SSTRIP is not set'
				apply_symbol 'CONFIG_STRIP_ARGS="--strip-all"'
				# CONFIG_PACKAGE_netdiscover=y
				# CONFIG_PACKAGE_tcpdump-mini=y
				# screen?
				# CONFIG_PACKAGE_gdb=y
				# CONFIG_PACKAGE_valgrind=y
			;;
			'revert'*|'revert12345')
				local rev="$( echo "$1" | cut -d't' -f2 )"		# revert12345 -> 12345
				local hash="$( git log --format=%h --grep="@$rev " )"
				local message

				if [ -n "$hash" ]; then
					message="$( git show -s --pretty=oneline --format=%B "$hash" | head -n1 )"
					autocommit "git revert $hash --no-commit" "reverting r$rev ($message)"
				else
					log "[ERR] commit $rev not found, ignoring"
				fi
			;;
			'iproute2')
				# TODO: do not include the 'ip neigh' patch with new busybox (e.g. v1.24.1),
				#	it is included upstream with 69934701fd1b18327b3a779cb292a728834b2d0d
				#	= Wed Oct 14 12:53:47 2015 +0200

				busybox_ip_command_is_prefered()
				{
					return 1	# till segfaults are gone and 'ip neigh add/change/replace' is there

					# https://dev.openwrt.org/changeset/46829/trunk
					test $( openwrt_revision_number_get ) -lt 46829 && return 1

					# is busybox 'ip' included/default?
					grep -q ^'CONFIG_BUSYBOX_DEFAULT_IP=y' '.config'
				}	# parser_ignore

				if busybox_ip_command_is_prefered; then
					log '[OK] using busybox ip'

					apply_symbol 'CONFIG_BUSYBOX_CONFIG_ARPING=y'
					test $( openwrt_revision_number_get ) -lt 47387 && {
						apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_IP_RULE=y'
					}	# parser_ignore
					apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_IP_NEIGH=y'
					apply_symbol 'CONFIG_BUSYBOX_CONFIG_TELNETD=y'
				else
					log '[OK] using full iproute2'
					apply_symbol 'CONFIG_PACKAGE_ip=y'		# network: routing/redirection: ip
					apply_symbol 'CONFIG_PACKAGE_ip-full=y'		# since lede 2016-oct-13
					apply_symbol 'CONFIG_BUSYBOX_CONFIG_ARPING=y'
#					apply_symbol 'CONFIG_BUSYBOX_CONFIG_TELNETD=y'		# FIXME
					apply_symbol 'CONFIG_BUSYBOX_DEFAULT_IP is not set'
					apply_symbol 'CONFIG_BUSYBOX_CONIG_IP is not set'
					apply_symbol 'CONFIG_BUSYBOX_CONFIG_FEATURE_IP_RULE is not set'
				fi

				apply_symbol 'CONFIG_PACKAGE_kmod-ipip=y'
			;;
			'queryMII')
				# deprecated! (we now use 'devstatus' for query MII)
				if [ -e "$KALUA_DIRNAME/openwrt-addons/etc/kalua/switch" ]; then
					log "[OK] checking if ethtool is needed for '$HARDWARE_MODEL'"

					# really ugly, but it avoids code duplication
					. $KALUA_DIRNAME/openwrt-addons/etc/kalua/switch
					HARDWARE="$HARDWARE_MODEL"

					# overwrite the main function - we just want
					# to know, if somebody calls '_switch query_mii'
					_switch()	# parser_ignore
					{
						[ "$1" = 'query_mii' ] && NEEDS_MII='true'
					}		# parser_ignore

					_switch_show	# TODO: fake _log()?

					if [ -n "$NEEDS_MII" ]; then
						# before r45995 it was: CONFIG_PACKAGE_mii-tool=y but 'musl' broke it - fixed with xy!
						$funcname subcall 'CONFIG_PACKAGE_ethtool=y'
					else
						log '[OK] no MII needed'
						return 1
					fi
				else
					log '[ERR] cannot autodetect if "queryMIIinterface" is needed - please apply this usecase manually if needed'
					return 1
				fi
			;;
			'1043NDv1_4mb_hack')
				# FIXME! this is not enough, on firstboot it still tries to format whole flash
				log "fooling profile to 4mb size" gitadd 'target/linux/ar71xx/image/Makefile'
				sed -i 's|(Device\/tplink-8m)|(Device\/tplink-4m)|g' 'target/linux/ar71xx/image/Makefile'
			;;
			'fotobox')
				$funcname subcall 'smbmount'
				$funcname subcall 'jpeg-tools'
			;;
			'jpeg-tools')
				apply_symbol 'CONFIG_PACKAGE_jpeg-tools=y'
			;;
			'smbmount')
				apply_symbol 'CONFIG_PACKAGE_kmod-fs-cifs=y'
				apply_symbol 'CONFIG_PACKAGE_cifsmount=y'
				apply_symbol 'CONFIG_PACKAGE_samba36-client=y'
			;;
			'wwan')
				# https://wiki.openwrt.org/doc/uci/network#protocol_wwan_usb_modems_autodetecting_above_protocols
				$funcname subcall 'QMI'
				$funcname subcall 'comgt'
			;;
			'comgt')
				# https://wiki.openwrt.org/doc/recipes/3gdongle
				apply_symbol 'CONFIG_PACKAGE_comgt=y'
				apply_symbol 'CONFIG_PACKAGE_comgt-directip=y'
				apply_symbol 'CONFIG_PACKAGE_comgt-ncm=y'

				apply_symbol 'CONFIG_PACKAGE_kmod-usb-serial-option=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-serial-wwan=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-acm=y'

				apply_symbol 'CONFIG_PACKAGE_sdparm=y'
			;;
			'QMI')
				# http://wiki.openwrt.org/doc/recipes/ltedongle
				# http://trac.gateworks.com/wiki/wireless/modem
				# https://www.dd-wrt.com/wiki/index.php/3G_/_3.5G
				#
				# uqmi -d /dev/cdc-wdm0 --verify-pin1 $PIN
				# uqmi -d /dev/cdc-wdm0 --get-data-status
				# uqmi -d /dev/cdc-wdm0 --get-signal-info
				# uqmi -d /dev/cdc-wdm0 --start-network $APN
				apply_symbol 'CONFIG_PACKAGE_uqmi=y'
				apply_symbol 'CONFIG_PACKAGE_usb-modeswitch=y'
				$funcname subcall 'USBserial'
			;;
			'OWM')
				# http://openwifimap.net
				apply_symbol 'CONFIG_PACKAGE_luci-app-owm=y'
				apply_symbol 'CONFIG_PACKAGE_luci-app-owm-ant is not set'
				apply_symbol 'CONFIG_PACKAGE_luci-app-owm-cmd=y'
				apply_symbol 'CONFIG_PACKAGE_luci-app-owm-gui is not set'
				apply_symbol 'CONFIG_PACKAGE_luci-lib-httpclient=y'
				apply_symbol 'CONFIG_PACKAGE_luaneightbl=y'
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
				apply_symbol 'CONFIG_PACKAGE_kmod-tg3 is not set'	# FIXME! dirty workaround/unneeded ethernet driver
				# apply_symbol 'CONFIG_PACKAGE_B43_DEBUG=y'
			;;
			'WiFi-rtl8192cu'|'WiFi-'*)
				# generic approach:
				# e.g usb-wifi-stick: rtl8192cu -> WiFi-rtl8192cu
				#                     ath9k-htc -> WiFi-ath9k-htc
				#                     rt2870    -> WiFi-rt2x00-usb	# dual-band/1 radio
				# ID 7392:7811 Edimax Technology Co., Ltd EW-7811Un 802.11n Wireless Adapter [Realtek RTL8188CUS]
				# or
				# CONFIG_PACKAGE_kmod-ath5k=y -> WiFi-ath5k
				#
				# ath9k_htc: check:
				# Netgear WNDA3200
				# D-Link DWA-126
				# Sony UWA-BR100
				# TP-LINK TL-WN821N v3

				kmod="$( echo "$1" | cut -d'-' -f2- )"			# WiFi-rtl8192cu -> rtl8192cu
				apply_symbol "CONFIG_PACKAGE_kmod-${kmod}=y"		# kernel-modules: wireless:
				case "$kmod" in
					*'ath'*)
						apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'
					;;	# parser_ignore
				esac
			;;
			'screen')
				apply_symbol 'PACKAGE_screen=y'
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
				apply_symbol 'CONFIG_PACKAGE_block-mount=y'		# base-system: +15k
			;;
			'USBethernet')
				apply_symbol 'PACKAGE_kmod-usb-net-dm9601-ether=y'	# kernel-modules: usb-support:
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
				apply_symbol 'CONFIG_PACKAGE_motion=y'
			;;
			'FFmpeg')
				apply_symbol 'CONFIG_PACKAGE_libffmpeg=y'
			;;
			'FFmpegmini')
				apply_symbol 'CONFIG_PACKAGE_libffmpeg-mini=y'
			;;
			'Photograph')
				$funcname subcall 'USBcam'
				apply_symbol 'CONFIG_PACKAGE_fswebcam=y'		# multimedia:
			;;
			'DSLR')
				# http://en.wikipedia.org/wiki/Digital_single-lens_reflex_camera
				# https://forum.openwrt.org/viewtopic.php?id=41957
				# http://www.inetcom.ch/dslr-trifft-openwrt-dslrdashboard-tl-mr3040
				# http://www.foto-webcam.eu/wiki/
				apply_symbol 'CONFIG_PACKAGE_gphoto2=y'			# multimedia
				apply_symbol 'CONFIG_PACKAGE_libgphoto2-drivers'	# libraries
			;;
			'USBcam')
				apply_symbol 'CONFIG_PACKAGE_kmod-video-core=y'
				apply_symbol 'CONFIG_PACKAGE_kmod-video-uvc=y'
				apply_symbol 'CONFIG_PACKAGE_v4l-utils=y'
				# TODO: include usbreset?
			;;
			'USBaudio')
				apply_symbol 'CONFIG_PACKAGE_coreutils=y'
				apply_symbol 'CONFIG_PACKAGE_coreutils-stdbuf=y'
				apply_symbol 'CONFIG_PACKAGE_madplay=y'			# sound: madplay
				apply_symbol 'CONFIG_PACKAGE_kmod-sound-core=y'		# kernel-modules: sound:
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-audio=y'		# ...
#				apply_symbol 'CONFIG_PACKAGE_kmod-input-core=y'		# ...
			;;
			'MPDmini')
				# + 1.5mb -> 1043er = too slow
				apply_symbol 'CONFIG_PACKAGE_mpd-mini=y'		# sound: mpd-mini
			;;
			'icecast')
				apply_symbol 'CONFIG_PACKAGE_icecast=y'			# multimedia:
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
			'vtunFull')
				apply_symbol 'CONFIG_PACKAGE_vtun=y'			# network: vpn: vtun:
#				apply_symbol 'CONFIG_VTUN_SSL is not set'		# ...
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

				# TODO: mini:
				# CONFIG_PACKAGE_olsrd-mod-dyn-gw-plain is not set
				# CONFIG_PACKAGE_olsrd-mod-jsoninfo is not set
				# CONFIG_PACKAGE_olsrd-mod-nameservice is not set

				$funcname subcall 'macVLAN'
			;;
			'OLSRd2')
				apply_symbol 'CONFIG_PACKAGE_olsrd2-git=y'		# network: olsrd2-framework
				apply_symbol 'CONFIG_PACKAGE_oonf-olsrd2-git=y'		# the same, but newer revisions
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH=y'
				apply_symbol 'CONFIG_PACKAGE_hnetd-nossl=y'
				apply_symbol 'CONFIG_OONF_NHDP_AUTOLL4=y'
				apply_symbol 'CONFIG_OONF_OLSRV2_LAN_IMPORT=y'
				apply_symbol 'CONFIG_OONF_OLSRV2_ROUTE_MODIFIER=y'
				apply_symbol 'CONFIG_OONF_GENERIC_REMOTECONTROL=y'
			;;
			'babel')
				apply_symbol 'CONFIG_PACKAGE_babeld=y'			# +50k
			;;
			'bmx7')
				apply_symbol 'CONFIG_PACKAGE_bmx7=y'		# network: routing/redirection:
				apply_symbol 'CONFIG_PACKAGE_bmx7-json=y'
				apply_symbol 'CONFIG_PACKAGE_bmx7-uci-config=y'
			;;
			'cjdns')
				apply_symbol 'CONFIG_PACKAGE_cjdns=y'
			;;
			'wibed')
				$funcname subcall 'OLSRd'
				$funcname subcall 'OLSRd2'
				$funcname subcall 'babel'
				$funcname subcall 'bmx7'
				$funcname subcall 'BatmanAdv'
				$funcname subcall 'cjdns'
				$funcname subcall 'GNUnet'

				$funcname subcall 'USBstorage'
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
			'GNUnet')
				apply_symbol 'CONFIG_PACKAGE_gnunet=y'
				apply_symbol 'CONFIG_PACKAGE_gnunet-transport-http_server=y'
			;;
			'GNUnet-full')
				$funcname subcall 'GNUnet'

				apply_symbol 'CONFIG_PACKAGE_gnunet-fs=y'
				apply_symbol 'CONFIG_PACKAGE_gnunet-utils=y'
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
				# be careful: failsafe-mode does not work without telnet (and no uhttpd)
				apply_symbol 'CONFIG_PACKAGE_dropbear is not set'

				# https://dev.openwrt.org/changeset/46809/trunk - (telnet removal)
				$funcname subcall 'revert46809'
			;;
			'noHTTPd')
				apply_symbol 'CONFIG_PACKAGE_uhttpd is not set'
			;;
			'noDebug')
				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG is not set'
				apply_symbol 'CONFIG_PACKAGE_MAC80211_DEBUGFS is not set'
				apply_symbol 'CONFIG_PACKAGE_libiwinfo is not set'	# -41k
				apply_symbol 'CONFIG_PACKAGE_iwinfo is not set'		# -23k

				apply_symbol kernel 'CONFIG_DEBUG_FS is not set'
				apply_symbol kernel 'CONFIG_KALLSYMS is not set'
				apply_symbol kernel 'CONFIG_DEBUG_KERNEL is not set'
				apply_symbol kernel 'CONFIG_DEBUG_INFO is not set'
				apply_symbol kernel 'CONFIG_ELF_CORE is not set'

				# these are newer symbols than avove, which does the same:
				apply_symbol 'CONFIG_PKG_CHECK_FORMAT_SECURITY is not set'
				apply_symbol 'CONFIG_KERNEL_ELF_CORE is not set'

				apply_symbol 'CONFIG_KERNEL_DEBUG_KERNEL is not set'
				apply_symbol 'CONFIG_KERNEL_DEBUG_INFO is not set'

				apply_symbol 'CONFIG_KERNEL_KALLSYMS is not set'
				apply_symbol 'CONFIG_KERNEL_DEBUG_FS is not set'
				apply_symbol 'CONFIG_KERNEL_CRASHLOG is not set'

				apply_symbol 'CONFIG_STRIP_KERNEL_EXPORTS=y'
				apply_symbol 'CONFIG_USE_MKLIBS=y'

				$funcname subcall 'noPrintK'
			;;
			'noIPv6')
				# TODO:
				# https://dev.openwrt.org/ticket/5586#comment:9

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
				apply_symbol 'CONFIG_PACKAGE_kmod-nf-conntrack6 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-nf-ipt6 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-ipv6 is not set'	# again?
			;;
			'noOPKG')
				apply_symbol 'CONFIG_PACKAGE_opkg is not set'		# base-system: opkg
				apply_symbol 'CONFIG_PACKAGE_usign is not set'		# since r45283 - FIXME! still in image

				mkdir -p 'files/etc'

				# .../trunk/ramips/mt7620/packages
				cat >'files/etc/opkg.conf' <<EOF
dest root /
dest ram /tmp
lists_dir ext /var/opkg-lists
option overlay_root /overlay
src/gz chaos_calmer_base http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/base
src/gz chaos_calmer_luci http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/luci
src/gz chaos_calmer_management http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/management
src/gz chaos_calmer_oldpackages http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/oldpackages
src/gz chaos_calmer_olsrd2 http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/olsrd2
src/gz chaos_calmer_oonfapi http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/oonfapi
src/gz chaos_calmer_packages http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/packages
src/gz chaos_calmer_routing http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/routing
src/gz chaos_calmer_telephony http://downloads.openwrt.org/snapshots/trunk/$ARCH/$ARCH_SUB/packages/telephony
EOF
				log "noOPKG: write missing 'files/etc/opkg.conf'" gitadd 'files/etc/opkg.conf'
			;;
			'noPPPoE')
				apply_symbol 'CONFIG_PACKAGE_ppp is not set'		# network: ppp
				apply_symbol 'CONFIG_PACKAGE_kmod-ppp is not set'	# kernel-modules: network-support: ppp
				apply_symbol 'CONFIG_PACKAGE_kmod-pppoe is not set'	# needed?
				apply_symbol 'CONFIG_PACKAGE_kmod-pppox is not set'	# needed?
			;;
			'noPrintK')
				# autoselected from 'noDebug'
				apply_symbol 'CONFIG_BUSYBOX_CONFIG_DMESG is not set'

				apply_symbol kernel 'CONFIG_PRINTK is not set'		# general setup: standard kernel features
				apply_symbol kernel 'CONFIG_EARLY_PRINTK is not set'	# kernel hacking: early printk
				apply_symbol kernel 'CONFIG_SYS_HAS_EARLY_PRINTK is not set'

				# newer/lede:
				apply_symbol 'CONFIG_KERNEL_PRINTK is not set'
				apply_symbol 'CONFIG_KERNEL_PRINTK_TIME is not set'
			;;
			'noAP')
				# autoselected from 'noWIFI'
				apply_symbol 'CONFIG_PACKAGE_wpad-mini is not set'
				apply_symbol 'CONFIG_PACKAGE_hostapd-common is not set'
			;;
			'noWIFI')
				apply_symbol 'CONFIG_PACKAGE_kmod-b43 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-ath5k is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-ath9k-common is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-ath9k is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-ath is not set'

				apply_symbol 'CONFIG_PACKAGE_kmod-cfg80211 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-mac80211 is not set'
				apply_symbol 'CONFIG_PACKAGE_kmod-mac80211-hwsim is not set'

				apply_symbol 'CONFIG_PACKAGE_iw is not set'
				$funcname subcall 'noAP'
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

				parse_case_patterns "$funcname" | while read -r line; do {
					if [ "$subcall" = 'plain' ]; then
						echo "$line"
					else
						echo "--usecase $line"
					fi
				} done

				[ "$subcall" = 'plain' ] || {
					echo
					echo '# or short:'

					printf '%s' '--usecase '
					parse_case_patterns "$funcname" | while read -r line; do {
						printf '%s' "$line,"
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

		case "$USECASE" in
			'CONFIG_'*)
				return 1
			;;
			'')
				echo	# last command does not set the cursor at line begin ("Collecting package info: done")
				return 1
			;;
			*)
				case "$SPECIAL_OPTIONS" in
					*"$USECASE"*)
						return 1
					;;
					*)
						# FIXME! USECASE e.g. b43mini,Standard,kalua@0e25ad4
						log "YES: needs adding: $USECASE"
						return 0
					;;
				esac
			;;
		esac
	}

	mkdir -p "$custom_dir/etc"
	file="$custom_dir/etc/openwrt_build"

	if buildinfo_needs_adding ; then
		echo "$USECASE" >"$file"
		log "adding build-information '$USECASE' to '$file'" gitadd "$file"
	else
		echo "${subcall:-$USECASE}" >>"${file}.details"
		log "just tempfile" debug,gitadd "${file}.details"
	fi
}

parse_case_patterns()
{
	local fname="$1"		# function to parse
	local start_parse line temp

	# the idea is to get all possible arguments for a function
	# by parsing it line for line and grep all 'case' statements.
	# this is ugly, but has the advantage that we do not need to
	# maintain a special list, e.g.
	#
	# function_xy()
	# {
	#   case "$1" in
	#     option1|option2)
	#     ;;
	#     optionN)
	#     ;;
	#   esac
	# }
	#
	# running our parser on this function will output 'option1 option2 optionN'

	while read -r line; do {
		if [ "$start_parse" = 'true' ]; then
			case "$line" in
				*'# parser_ignore'*)
					continue
				;;
			esac

			case "$line" in
				*')'*)
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

mimetype_get()
{
	local file="$1"
	local mimetype link

	link="$( readlink "$file" )" && file="$link"	# e.g. /tmp/loader

	set -- $( file '--mime-type' "$file" )
	mimetype="$*"
	mimetype=${mimetype##* }	# last word

	case "$mimetype" in
		'text/html')
			case "$( basename "$file" )" in
				*'.js'*)
					# e.g. 'sorttable.js_googleclosure.includeable2'
					# support missing:
					# https://github.com/file/file/blob/master/magic/Magdir/javascript
					mimetype='application/javascript'
				;;
				*'.txt')
					mimetype='text/plain'
				;;
			esac
		;;
	esac

	echo "$mimetype"
}

list_shellfunctions()
{
	local file="$1"

	# see https://github.com/koalaman/shellcheck/issues/529
	grep -s '^[a-zA-Z_][a-zA-Z0-9_]*[ ]*()' "$file" | cut -d'(' -f1
}

check_scripts()
{
	local funcname='check_scripts'
	local dir="$1"		# or file
	local tempfile='/tmp/check_scripts'
	local tempfile_functions="$tempfile.functions"
	local good='true'
	local i=0
	local file mimetype

	find "$dir" -type f -not -iwholename '*.git*' >"$tempfile"

	while read -r file; do {
		mimetype="$( mimetype_get "$file" )"

		case "$mimetype" in
			'text/plain')
				log "[OK] will NOT check '$mimetype' file '$file'" debug
			;;
			'inode/x-empty'|'application/x-empty')
				log "[OK] will NOT check empty file '$file'" debug
			;;
			'text/html')
				if command -v tidy >/dev/null; then
					case "$( head -n1 "$file" )" in
						'<!DOCTYPE html>')
							log "[IGNORE] tidy/HTML5: '$file' see: http://foswiki.org/Tasks/Item13134"
						;;
						*)
							case "$file" in
								*'map1.html'|*'map2.html')
									log "[IGNORE] will NOT check '$mimetype' file '$file' (special)"
								;;
								*)
									log "html: checking '$mimetype' / $file"
									tidy -errors "$file" || return 1
								;;
							esac
						;;
					esac
				else
					log "[IGNORE] will NOT check '$mimetype' file '$file' - missing 'tidy'"
				fi
			;;
			'text/x-php')
				if command -v php >/dev/null; then
					log "checking '$mimetype' / $file"
					php --syntax-check "$file" || return 1
				else
					log "[IGNORE] will NOT check '$mimetype' file '$file' - missing 'php'"
				fi
			;;
			'text/x-c'|'text/x-c++')
				# cppcheck?
				if command -v cppcheck >/dev/null; then
					cppcheck "$file" || return 1
				else
					log "[IGNORE] will NOT check '$mimetype' file '$file' - missing 'cppcheck'"
				fi
			;;
			'application/javascript')
				# https://github.com/marijnh/acorn -> install node.js + npm?
				#  - https://marijnhaverbeke.nl/fund/
				# TODO: autoextract <script>...</script> snippets from HTML?
				if command -v acorn >/dev/null; then
					log "checking '$mimetype' / $file"
					case "$file" in
						*'googleclosure'*)
							log "[OK] ignoring '$file' FIXME"	# FIXME!
						;;
						*)
							acorn --silent "$file" || return 1
						;;
					esac
				else
					log "[IGNORE] will NOT check '$mimetype' file '$file' - missing 'acorn'"
				fi
			;;
			'image/gif')
				# imagemagick?
				log "[IGNORE] will NOT check gfx file '$file' - TODO/imagemagick"
			;;
			'application/octet-stream'|'application/x-gzip'|'text/x-diff'|'application/x-executable')
				log "[IGNORE] will NOT check binary file '$file'" debug
			;;
			'text/x-shellscript')
				log "checking '$mimetype' / $file"
				sh -n "$file" || {
					log "error in file '$file' - abort"
					good='false'
					break
				}
				i=$(( i + 1 ))

				list_shellfunctions "$file" >>"$tempfile_functions"
			;;
			*)
				log "[FIXME] will NOT check - unknown mimetype: '$mimetype' file: '$file' pwd: '$( pwd )'"
			;;
		esac
	} done <"$tempfile"

	if [ "$good" = 'true' ]; then
		[ ${i:=0} -eq 0 ] || {
			log "[OK] checked $i shellfiles with $( wc -l 2>/dev/null <"$tempfile_functions" ) shell-functions"
		}
	else
		i=-1
	fi

	rm "$tempfile" "$tempfile_functions" 2>/dev/null
	test $i -ge 0
}

buildhost_arch()
{
	# e.g. i386 or amd64
	dpkg --print-architecture
}

travis_prepare()
{
	log "[OK] debug 'mount'/'ip'"
	echo '# ---'
	mount
	ip address show
	echo '# ---'

	local apt_updated=
	do_install()
	{
		[ -z "$apt_updated" ] && {
			log "[OK] running 'apt-get update'"
			sudo apt-get update || return 1
			apt_updated='true'
		}

		log "[OK] trying 'apt-get install $*'"
		sudo apt-get -y install "$@" || {
			# sometimes it bails out without good reason
			log "[ERR] during 'apt-get install $*', but trying to continue..."
		}
	}

	# http://ctags.sourceforge.net -> buggy
	# https://github.com/universal-ctags/ctags.git
	bootstrap_ctags		|| return 1

	# TODO: check again after 'do_install'
	command -v 'pip'	|| do_install 'pip'		|| return 1	# for codespell
	# https://github.com/lucasdemarchi/codespell
	command -v 'codespell.py' || sudo pip install codespell	|| return 1
	# http://www.dwheeler.com/sloccount/sloccount-2.26.tar.gz
	command -v 'sloccount'	|| do_install 'sloccount'	|| return 1
	# http://www.html-tidy.org/
	command -v 'tidy'	|| do_install 'tidy'		|| return 1
	# http://de1.php.net/distributions/php-5.6.14.tar.bz2
	php --version | grep -q ^'PHP 5\.' || do_install 'php5'	|| return 1
	# for javascript testing: https://github.com/marijnh/acorn
	command -v 'nodejs'	|| do_install 'nodejs'		|| return 1
	command -v 'npm'	|| do_install 'npm'		|| return 1
	# forces http NOT https:
	sudo $( command -v 'npm' ) config set registry http://registry.npmjs.org/
	# https://www.npmjs.com/package/acorn - javascript-parser/checker
	sudo $( command -v 'npm' ) install --global 'acorn'	|| return 1

	export PATH="$HOME/.cabal/bin:$PATH"
	if command -v shellcheck; then
		log "[OK] no need for building 'shellcheck'"
	else
		bootstrap_shellsheck || return 1
		command -v shellcheck || return 1
	fi
}

bootstrap_ctags()
{
	local url='https://github.com/universal-ctags/ctags.git'
	local dir='ctags'
	local date="$( LC_ALL=C date "+%b %_d %Y" )"	# e.g. 'Oct  1 2016'
	local good_version='48e382b94dac8ed8bf4b360c0ce4dd01c21bc5de'
	good_version='9668032d8715265ca5b4ff16eb2efa8f1c450883'		# 2017-jan-8 (including new sh-parser)

	/tmp/$dir/ctags --version | grep -q "Compiled: $date" || {
		(
			cd '/tmp' || return 1
			[ -d "$dir" ] && rm -fR "$dir"
			git clone "$url"
			cd "$dir" || return 1
			git checkout -b 'good_version' "$good_version"

			log '[OK] used commit:'
			git log -1

			log '[OK] autogen:'
			./autogen.sh || return 1

			log '[OK] configure:'
			./configure || return 1

			log '[OK] make:'
			if make; then
				log '[OK] make success'
			else
				log "[ERR] make: $? - rebuild with V=99"
				make V=99

				return 1
			fi
		)
	}

	export PATH="/tmp/$dir:$PATH"
	ctags --version
	ctags --version | grep "Compiled: $date"
}

bootstrap_shellsheck()
{
	[ -n "$TRAVIS" ] && {
		local myarch="$( buildhost_arch )"
		local url="http://ftp.debian.org/debian/pool/main/s/shellcheck/shellcheck_0.4.4-4_${myarch}.deb"

		# TODO: build-static: https://github.com/koalaman/shellcheck/issues/758
		wget -O 'shellsheck.deb' "$url"
		sudo dpkg -i 'shellsheck.deb'

		return $?
	}

	# needs ~15 mins
	(
		cabal update
		cabal install --verbose=3 'cabal-install' || {
			log "[ERR] cabal-install"
			cat "$HOME/.cabal/logs/cabal-install-"*.log
		}

		cd '/run/shm' || return 1
		git clone https://github.com/koalaman/shellcheck.git
		cd shellcheck || return 1

		log '[OK] last commit:'
		git log -1

		# https://github.com/haskell/cabal/issues/2909
		cabal install || ghc-pkg check
	)
}

unittest_do()
{
	local funcname='unittest_do'
	local start_test build_loader
	local uid="$( id -u )"

	if [ "$KALUA_DIRNAME" = 'openwrt-build' -o -e '../build.sh' -o -e 'openwrt-build/build.sh' ]; then
		build_loader='openwrt-addons/etc/kalua_init'
		start_test='tests/test_all.sh'
	else
		build_loader="$KALUA_DIRNAME/openwrt-addons/etc/kalua_init"
		start_test="$KALUA_DIRNAME/tests/test_all.sh"
	fi

	log '[START]'
	log "build and symlink loader: $build_loader uid: $uid"
	if [ $uid -eq 0 ]; then
		$build_loader "$funcname" || return 1
		ln -sf "$build_loader" '/etc/kalua_init' || return 1
	else
		sudo $build_loader "$funcname" || return 1
		sudo ln -sf "$build_loader" '/etc/kalua_init' || return 1
	fi
	log "[OK] setting $build_loader -> /tmp/loader symlink needed sudo"
	log "used PATH in loader:"
	grep 'PATH=' '/tmp/loader' || log "(no PATH set)"

	log "testing '/tmp/loader'"
	sh -n '/tmp/loader' || return 1

	log "executing '$start_test'"
	$start_test 'now' || {
		log "search for pattern '^--' when this is a shellsheck error or search 'try: codespell.py' for spell mistakes"
		return 1
	}
}

check_git_settings()
{
	local funcname='check_git_settings'

	[ -d ~/.git ] || mkdir ~/.git

	# is relevant, if we commit something -> autocommits during build!
	git config 'user.email' >/dev/null || {
		log "please set: git config user.email 'your@email.tld'"
		return 1
	}

	git config 'user.name'  >/dev/null || {
		log "please set: git config user.name 'Your Name'"
		return 1
	}
}

# or: --myrepo 'git://github.com/weimarnetz/weimarnetz.git'

if [ -e 'KALUA_REPO_URL' ]; then
	read -r KALUA_REPO_URL <'KALUA_REPO_URL'
else
	KALUA_REPO_URL='git://github.com/bittorf/kalua.git'
fi

KALUA_DIRNAME="$( basename "$KALUA_REPO_URL" | cut -d'.' -f1 )"		# e.g. kalua|weimarnetz
PATCHDIR=

if [ -z "$1" ]; then
	openwrt_download 'reset_autocommits'
	print_usage_and_exit
else
	ARGUMENTS_MAIN="$*"
	log "parsing your args: $ARGUMENTS_MAIN"
fi

while [ -n "$1" ]; do {
	case "$1" in
		'--tarball_package'|'-P')
			build_tarball_package || print_usage_and_exit
			exit 0
		;;
		'--info'|'-i')
			target_hardware_set "${2:-$( cat files/etc/HARDWARE )}" info
			exit 0
		;;
		'--dotconfig')
			if [ -e "$2" ]; then
				BACKUP_DOTCONFIG="$2"
				log "[OK] using .config from '$BACKUP_DOTCONFIG'"
			else
				log "[ERROR] cannot find '$2'"
				exit 1
			fi
		;;
		'--feedstime')
			FEEDSTIME="$2"	# e.g. '2015-08-31 19:33' or <empty> = fresh
			FEEDSNAME="$3"	# e.g. 'luci' or <empty> = all
		;;
		'--check'|'-c')
			log "KALUA_DIRNAME: '$KALUA_DIRNAME' \$0: $0" debug

			if [ "$KALUA_DIRNAME" = "$( dirname "$0" )" -o -e '../build.sh' -o -e 'openwrt-build/build.sh' ]; then
				# openwrt-build/build.sh -> openwrt-build
				check_scripts .
			else
				check_scripts "${2:-$KALUA_DIRNAME}"
			fi

			test $? -eq 0 || exit 1
			STOP_PARSE='true'
		;;
		'--update')
			ME="$0"
			STOP_PARSE='true'
			URL='https://raw.githubusercontent.com/bittorf/kalua/master/openwrt-build/build.sh'

			CRC_OLD="$( md5sum <"$ME" )"
			if wget -O "$ME.tmp" "$URL"; then
				CRC_NEW="$( md5sum <"$ME.tmp" )"
				if [ "$CRC_OLD" = "$CRC_NEW" ]; then
					rm "$ME.tmp"
					log '[OK] nothing changed'
				else
					mv "$ME.tmp" "$ME" && chmod +x "$ME"
					log '[OK] new version installed'
				fi
			else
				log "please run manually:"
				log "wget --no-check-certificate -O '$ME' '$URL'"
			fi
		;;
		'--travis_prepare')
			travis_prepare || exit 1
			STOP_PARSE='true'
		;;
		'--unittest')
			unittest_do || exit 1
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
		'--nobuild')
			NOBUILD='true'
		;;
		'--download_pool')
			DOWNLOAD_POOL="$2"
		;;
		'--openwrt')
			case "$2" in
				'lede'|'lede-staging'|'trunk'|'10.03'|'12.09'|'14.07'|'15.05')
					# TODO: 15.05.1 ???
					VERSION_OPENWRT="$2"
					VERSION_OPENWRT_INTEGER=1	# no error in calculations
				;;
				'r'[0-9]*)
					VERSION_OPENWRT="$2"
					VERSION_OPENWRT_INTEGER="${2#*r}"
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
			# exact match in our list?
			if target_hardware_set 'list' 'plain' | grep -q ^"$2"$ ; then
				HARDWARE_MODEL="$2"
				[ "$3" = 'check_valid' ] && exit 0
			else
				# ARG3 = e.g. option 'plain' or 'json'
				# first try a submatch (e.g. 1043 or asus) - when this fails, show all
				target_hardware_set 'list' "$3" | grep -F "$2" || target_hardware_set 'list' "$3"

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

			[ "$3" = 'check_valid' ] && exit 0
		;;
		'--profile'|'-p')
			# e.g. ffweimar.hybrid.120
			CONFIG_PROFILE="$2"
		;;
		'--release'|'-r')
			case "$2" in
				'stable'|'beta'|'testing')
					RELEASE="$2"
					RELEASE_SERVER="$3"	# root@intercity-vpn.de:/var/www/networks/liszt28

					[ -z "$RELEASE_SERVER" ] && {
						log "[ERROR] --release $RELEASE user@server:/your/path/to/network"
						exit 1
					}
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
		'--myrepo'|'-m')
			# only valid after virgin build-script download
			KALUA_REPO_URL="$2"
		;;
		'--buildid')
			# e.g. 'user@domain.tld'
			# http://tjworld.net/wiki/Linux/Kernel/Build/CustomiseVersionString
			log "[OK] $1: set $2 via fake hostname/whoami in ~"

			# we will NOT remove the files!
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
		'--'*|'-'*)
			log "[ERR] invalid option '$1'"
			STOP_PARSE='true'
		;;
	esac

	shift
} done

[ -n "$STOP_PARSE" ] && exit 0
CPU_LOAD_INTEGER="$( cpu_load_integer )"	# see build() - how many parallel make jobs
get_uptime_in_sec 'T1'

die_and_exit()
{
	local branch="$( git branch | grep ^'* openwrt@' | cut -d' ' -f2 )"

	[ -n "$branch" ] && {
		log "[ATTENTION] you are on branch '$branch' now - better do: 'git checkout master' and"
		log "git branch | grep -v '* master' | while read LINE; do git branch -D \$LINE; done; git stash clear"
	}

	[ -n "$FORCE" ] && return 0

	log '[ERROR] the brave can try --force, all others should do: git checkout master'
	exit 1
}

# http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-5.1/man1/whoami.1?query=whoami&sec=1&manpath=OpenBSD-5%2e1
[ "$( id -u )" = '0' ] && log "REMINDER: do not build as root, you have UID: $( id -u )"

check_working_directory			|| die_and_exit
openwrt_download 'reset_autocommits'
openwrt_download "$VERSION_OPENWRT"	|| die_and_exit
check_git_settings			|| die_and_exit
feeds_prepare
feeds_adjust_version "$FEEDSTIME" "$FEEDSNAME"

[ -z "$HARDWARE_MODEL" ]    && print_usage_and_exit "you forgot to specifiy --hardware '\$MODEL'"
[ -z "$LIST_USER_OPTIONS" ] && print_usage_and_exit "you forgot to specifiy --usecase '\$USECASE'"

SPECIAL_OPTIONS=
[ -z "$BACKUP_DOTCONFIG" -a "$VERSION_OPENWRT" -a "$LIST_USER_OPTIONS" -a "$HARDWARE_MODEL" ] && \
	BACKUP_DOTCONFIG="KALUA_DOTCONFIG_${VERSION_OPENWRT}_${LIST_USER_OPTIONS}_${HARDWARE_MODEL}"

# FIXME! disabled for now, we must at least apply kalua-patchset
if [ -e "x$BACKUP_DOTCONFIG" ]; then
	log "[OK] will use already existing '.config' file: '$BACKUP_DOTCONFIG'"
else
	log "[OK] building .config = '$BACKUP_DOTCONFIG'"
	target_hardware_set "$HARDWARE_MODEL"	|| die_and_exit
	apply_patches				|| die_and_exit
	copy_additional_packages		|| die_and_exit
	build_options_set "$SPECIAL_OPTIONS"	|| die_and_exit
	build_options_set "$LIST_USER_OPTIONS"	|| die_and_exit		# here we build '$USECASE'
	build_options_set 'ready'
fi

if [ "$NOBUILD" = 'true' ]; then
	get_uptime_in_sec 'T2'
	log "[OK] stopping just before build (needed $( calc_time_diff "$T1" "$T2" ) sec)"
	exit 1
else
	build					|| exit 1
	copy_firmware_files			|| die_and_exit
	openwrt_download 'switch_to_master'
	openwrt_download 'reset_autocommits'
fi

get_uptime_in_sec 'T2'

echo "$USECASE $HARDWARE_MODEL" >>'KALUA_HISTORY'
[ -n "$BACKUP_DOTCONFIG" ] && {
	{
		echo '# please strip with:'
		echo '# sed -e "/^#/d" -e "/^$/d" -e "/^CONFIG_DEFAULT_/d" -e "/^CONFIG_BUSYBOX_DEFAULT_/d" "THIS_FILE"'
		echo
		cat '.config'
	} >"$BACKUP_DOTCONFIG"
}

log "[OK] - Jauchzet und frohlocket, ob der Bytes die erschaffen wurden in $( calc_time_diff "$T1" "$T2" ) sek."
target_hardware_set "$HARDWARE_MODEL" info quiet >/dev/null && log "[OK] - more info via: $0 --info '$HARDWARE_MODEL'"
log "[OK] - check size of files with: find bin/$ARCH_MAIN -type f -exec stat -c '%s %N' {} \; | grep -v '/attic/' | sort -n"

exit 0
