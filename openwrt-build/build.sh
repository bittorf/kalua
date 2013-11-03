#!/bin/sh

# ToDo:
# - kalua/custom files to '<buildroot dir>/files/'
# - kcmdlinetweak
# - apply kernel_symbols
#   - NO: ??? /home/bastian/j/openwrt/build_dir/target-mips_34kc_uClibc-0.9.33.2/linux-ar71xx_generic/linux-3.10.17/.config
#   - back to normal state: git checkout -- /home/bastian/j/openwrt/target/linux/ar71xx/config-3.10
# - detect kernel_version
# - options: USBaudio, BigBrother, micro, mini, small, LuCI, noWiFi, noSSH (+login-patch), noOPKG, noIPTables, Failsafe
# - kalua: checkout specific version
# - packages/feeds/openwrt: checkout specific version
# - build release-dir
# - hardware: all models
# - build jffs2-images too
# - apply_profile

# dir-structure:
# $HARDWARE/testing/$files


# build: release = all arch's + .info-file upload + all options (nopppoe,audiplayer)

# hardware=	Ubiquiti Bullet M			// special, no option-name and separator='.'
# rootfs=	jffs2.64k | squash | ext4
# openwrt=	r38675
# kernel=	3.6.11
# image=	sysupgrade | factory | tftp | srec | ...
# profile=	liszt28.hybrid.4			// optional
# option=	Standard,USBaudio,BigBrother,kalua.5dce00c,VDS,failsafe,noIPv6,noPPPoE,micro,mini,small,LuCI
#
# 151 chars:
# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_option=kalua.5dce00c,Standard,VDS,BigBrother_profile=liszt28.hybrid.4_rootfs=squash_image=sysupgrade.bin
#
# build-syntax:
#
# build --openwrt r38675 --hardware 'Ubiquiti Bullet M' --option kalua,Standard,VDS,USBaudio,BigBrother,noIPv6,noPPPoE --profile liszt28.hybrid.4
# build --openwrt r38675 --hardware 'Ubiquiti Bullet M' --option kalua,Standard,VDS
# build --upload attic/stable/beta/testing --release (=sysupgrade-file without all details = 'Ubiquiti Bullet M.sysupgrade.bin'

log()
{
	local message="$1"

	logger -p user.info -s "$0: $message"
}

print_usage()
{
	cat <<EOF

Usage: $0 --openwrt r38675|trunk|<empty> = leave untouched
	  --hardware 'Ubiquiti Bullet M'|<empty> = list supported models
	  --option
	  --profile
	  --upload
	  --release

e.g. : $0 --openwrt trunk --hardware 'Ubiquiti Bullet M' --option kalua,Standard,VDS

EOF
}

target_hardware_set()
{
	local funcname='target_hardware_set'
	local model="$1"
	local line start_parse

	case "$model" in
		'TP-LINK TL-WR1043ND')
			TARGET_SYMBOL='CONFIG_TARGET_ar71xx_generic_TLWR1043=y'
			FILENAME_SYSUPGRADE='openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-ar71xx-generic-tl-wr1043nd-v1-squashfs-factory.bin'
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
			FILENAME_SYSUPGRADE='openwrt-au1000-au1500-sysupgrade.bin'
			FILENAME_FACTORY='openwrt-au1000-au1500-vmlinux-flash.srec openwrt-au1000-au1500-squashfs.srec'
		;;
		'list')
			log "$funcname() supported models:"
			parse_case_patterns "$funcname" | while read line; do {
				echo "--hardware '$line'"
			} done

			return 0
		;;
		*)
			log "model '$model' not supported"

			return 1
		;;
	esac

	ARCH="$( echo "$TARGET_SYMBOL" | cut -d'_' -f3 )"

	log "$funcname() architecure: '$ARCH' model: '$model'"

	apply_symbol 'nuke_config'
	apply_symbol "$TARGET_SYMBOL"
	build defconfig
}

openwrt_download()
{
	local funcname='openwrt_download'
	local wish="${1:-leave_untouched}"

	log "$funcname() apply '$wish'"

	case "$wish" in
		leave_untouched)
		;;
		trunk)
			# switch to master
			git pull
			scripts/feeds update
		;;
		r*)
			# checkout openwrt and feed at this date
		;;
	esac
}

copy_files()
{
	local funcname='copy_files'

	log "$funcname() not implemented yet"
	# tarball + .info + readme.markdown?
}

build()
{
	local funcname='build'
	local option="$1"
	local cpu_count="$( grep -c ^'processor' '/proc/cpuinfo' )"
	local jobs=$(( $cpu_count + 1 ))
	local commandline="--jobs $jobs"

	case "$option" in
		'nuke_bindir')
			log "$funcname() $option: rm -fR 'bin/$ARCH'"
			rm -fR "bin/$ARCH"
		;;
		'defconfig')
			log "$funcname() running 'make defconfig'"
			make defconfig
		;;
		*)
			log "$funcname() running 'make $commandline'"
			make $commandline
		;;
	esac
}

apply_symbol()
{
	local funcname='apply_symbol'
	local symbol="$1"
	local file='.config'
	local choice

	case "$symbol" in
		'kernel')
			log "$funcname() not implemented yet '$kernel' -> $2"
			return 0
			# target/linux/ar71xx/config-3.10
		;;
		'nuke_config')
			log "$funcname() starting with an empty config"
			rm "$file"

			build 'nuke_bindir'

			return 0
		;;
		'CONFIG_PACKAGE_ATH_DEBUG=y')
			# only when atheros-drivers are involved
			grep -q 'CONFIG_PACKAGE_kmod-ath=y' "$file" || return 0
		;;
	esac

	log "$funcname() $symbol"

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
	esac

	grep "$symbol=" "$file"
	grep "$symbol " "$file"
}

build_options_set()
{
	local funcname='build_options_set'
	local options="$1"
	local file='.config'

	local oldIFS="$IFS"; IFS=','; set -- $options; IFS="$oldIFS"
	while [ -n "$1" ]; do {
		log "$funcname() apply '$1'"

		case "$1" in
			'Standard')
				apply_symbol 'CONFIG_PACKAGE_zram-swap=y'		# base-system: zram-swap
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-ipopt=y'	# network: firewall: iptables:
				apply_symbol 'CONFIG_PACKAGE_iptables-mod-nat-extra=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_ip=y'			# network: routing/redirection: ip
				apply_symbol 'CONFIG_PACKAGE_kmod-macvlan=y'		# kernel-modules: network-devices:
				apply_symbol 'CONFIG_PACKAGE_uhttpd=y'			# network: webserver: uhttpd
				apply_symbol 'CONFIG_PACKAGE_uhttpd-mod-tls=y'		# ...
				apply_symbol 'CONFIG_PACKAGE_px5g=y'			# utilities: px5g
				apply_symbol 'CONFIG_PACKAGE_tc=y'			# network: tc
				apply_symbol 'CONFIG_PACKAGE_mii-tool=y'		# network: mii-tool:
				apply_symbol 'CONFIG_PACKAGE_p910nd=y'			# network: printing: p910
				apply_symbol 'CONFIG_PACKAGE_kmod-usb-printer=y'	# kernel-modules: other: kmod-usb-printer
				apply_symbol 'CONFIG_PACKAGE_rrdtool=y'			# utilities: rrdtool:
				apply_symbol 'CONFIG_PACKAGE_ATH_DEBUG=y'		# kernel-modules: wireless:
				apply_symbol 'CONFIG_PACKAGE_MAC80211_MESH is not set'	# ...
				apply_symbol 'CONFIG_PACKAGE_wireless-tools=y'		# base-system: wireless-tools

				$funcname 'vtun'
				$funcname 'OLSRd'
				$funcname 'BatmanAdv'
				$funcname 'noFW'
				$funcname 'ebTables'
			;;
			'Small')
				# 4mb flash - noPPPoE
			;;
			'Mini')
				# be careful: getting firmware and reflash must be possible (or bootloader with TFTP needed)
				# like small and: noMESH, noSSH, noOPKG, noSwap, noUHTTPD, noIPTables
			;;
			'Micro')
				# like mini and: noWiFi, noJFFS2-support
			;;
			### here starts all functions/packages, above are 'meta'-descriptions ###
			'vtun')
				apply_symbol 'CONFIG_PACKAGE_vtun=y'			# network: vpn: vtun:
				apply_symbol 'CONFIG_VTUN_SSL is not set'		# ...
			;;
			'OLSRd')
				apply_symbol 'CONFIG_PACKAGE_olsrd=y'			# network: routing/redirection: olsrd:
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-nameservice=y'	# ...
				apply_symbol 'CONFIG_PACKAGE_olsrd-mod-txtinfo=y'	# ...
			;;
			'BatmanAdv')
				apply_symbol 'CONFIG_PACKAGE_kmod-batman-adv=y'		# kernel-modules: support: batman-adv
			;;
			'ebTables')
				apply_symbol 'CONFIG_PACKAGE_kmod-ebtables=y'		# kernel-modules: netfilter-extensions:
			;;
			'VDS')
				apply_symbol 'CONFIG_PACKAGE_ulogd=y'			# network: ulogd:
				apply_symbol 'CONFIG_PACKAGE_ulogd-mod-extra=y'		# ...
			;;
			'noIPv6')
				apply_symbol 'CONFIG_IPV6 is not set'			# global build settings: IPv6 support in packages
				apply_symbol 'CONFIG_PACKAGE_6relayd is not set'	# network: 6relayd
				apply_symbol 'CONFIG_PACKAGE_odhcp6c is not set'	# network: odhcp6c
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
			'list')
				log "$funcname() supported options:"
				parse_case_patterns "$funcname" | while read line; do {
					echo "--option $line"
				} done

				echo
				echo '# or short:'

				echo -n '--option '
				parse_case_patterns "$funcname" | while read line; do {
					echo -n "$line,"
				} done
				echo

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
}

copy_files()
{
	local funcname='copy_files'

	log "$funcname() not implemented yet"
}

parse_case_patterns()
{
	local fname="$1"		# function to parse
	local start_parse line

	while read line; do {
		if [ "$start_parse" = 'true' ]; then
			case "$line" in
				*')')
					local oldIFS="$IFS"; IFS='|'; set -- $line; IFS="$oldIFS"
					while [ -n "$1" ]; do {
						case "$1" in
							"'list')")
								# parser at end of the function
								return 1
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

while [ -n "$1" ]; do {
	case "$1" in
		'--help'|'-h')
			print_usage
			exit 0
		;;
		'--openwrt')
			VERSION_OPENWRT="$2"
		;;
		'--hardware'|'-hw')
			case "$2" in
				'-'*|'')
					# next arg OR <empty>
					target_hardware_set 'list'
					exit 1
				;;
				*)
					HARDWARE_MODEL="$2"
					target_hardware_set "$HARDWARE_MODEL" || exit 1
				;;
			esac
		;;
		'--option'|'-o')
			case "$2" in
				'-'*|'')
					# next arg OR <empty>
					build_options_set 'list'
					exit 1
				;;
				*)
					LIST_OPTIONS="$2"
				;;
			esac
		;;
		'--profile'|'-p')
			CONFIG_PROFILE="$2"
		;;
		'--upload'|'-u')
		;;
		'--release'|'-r')
		;;
	esac

	shift
} done

[ -z "$HARDWARE_MODEL" -o -z "$LIST_OPTIONS" ] && {
	print_usage
	exit 1
}

openwrt_download "$VERSION_OPENWRT"	|| exit 1
build_options_set "$LIST_OPTIONS"	|| exit 1
build defconfig
build					|| exit 1
copy_files				|| exit 1
