#!/bin/sh

# build: release = all arch's + .info-file upload + all options (nopppoe,audiplayer)
# option=kalua,standard-flash4mb,noPPPoE,noIPv6
# option=standard-flash2mb
# CONFIG_TARGET_au1000=y
# CONFIG_TARGET_ar71xx=y
# ...

# naming-scheme:
# now:
#
# http://intercity-vpn.de/firmware/ar71xx/images/testing/
# Ubiquiti Bullet M.r38576-kernel3.10.17-git.5dce00c.factory.bin
# Ubiquiti Bullet M.r38576-kernel3.10.17-git.5dce00c.sysupgrade.bin
#
# later:
#
# hardware=	Ubiquiti Bullet M			// special, no option-name and separator='.'
# rootfs=	jffs2.64k | squash | ext4
# openwrt=	r38675
# kernel=	3.6.11
# image=	sysupgrade | factory | tftp | srec | ...
# profile=	liszt28.hybrid.4			// optional
# option=	Standard,USBaudio,BigBrother,kalua.5dce00c,VDS,failsafe,noIPv6,noPPPoE,micro,mini,small,LuCI
#
# standard = 8mb flash
# small = 4mb flash
# mini = noswap/zram + no uhttpd + noiptables + nopppoe + noipv6 + nodropbear + noopkg 
# micro = micro + nowifi
#
# 151 chars:
# Ubiquiti Bullet M.openwrt=r38576_kernel=3.6.11_option=kalua.5dce00c,Standard,VDS,BigBrother_profile=liszt28.hybrid.4_rootfs=squash_image=sysupgrade.bin
#
# build-syntax:
#
# build --openwrt r38675 --hardware 'Ubiquiti Bullet M' --option kalua,Standard,VDS,USBaudio,BigBrother,noIPv6,noPPPoE --profile liszt28.hybrid.4
# build --openwrt r38675 --hardware 'Ubiquiti Bullet M' --option kalua,Standard,VDS
# build --upload stable/beta/testing --release (=sysupgrade-file without all details = 'Ubiquiti Bullet M.sysupgrade.bin'

hardware()
{
	local model="$1"

	case "$model" in
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
		*)
			# throw error
		;;
	esac
}

# build --openwrt r38675 --hardware 'Ubiquiti Bullet M' --option kalua,Standard,VDS

checkout_openwrt_revision 	# +feeds at this date
set_target/arch			# Ubiquiti Bullet M / ar71xx
set_options			# kalua.5dce00c,VDS,Standard
build				# make -j25
copy_files			# tarball + .info + .readme

