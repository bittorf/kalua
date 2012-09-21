#!/bin/sh

# todo:
# - stick to specific git-revision
# - autodownload .definitions

log()
{
	logger -s "$( date ): [$( pwd )]: $0: $1"
}

[ -z "$1" ] && {
	log "Usage: $0 <hardware_model|get_list> <mini|standard|full>"
	exit 1
}

[ "$( id -u )" = "0" ] && {
	log "please run as normal user"
	exit 1
}

changedir()
{
	[ -d "$1" ] || {
		log "creating dir $1"
		mkdir -p "$1"
	}

	log "going into $1"
	cd "$1"
}

clone()
{
	local repo="$1"
	local dir="$( basename "$repo" | cut -d'.' -f1 )"

	if [ -d "$dir" ]; then
		log "git-cloning of '$repo' already done, just pulling"
		changedir "$dir"
		git pull
		changedir ..
	else
		log "git-cloning from '$repo'"
		git clone "$repo"
	fi
}

mymake()
{
	log "[START] executing 'make $1'"
	make $1
	log "[READY] executing 'make $1'"
}

# ath9kdebug
# b43minimal
# dataretention
# HARDWARE.mr3020
# HARDWARE.Ubiquiti Bullet M
# kernel.addzram
# luci
# meta.ffweimar
# nopppoe
# standard
# unencrypted_adhoc_only
# vtunZlibLZOnoSSL

prepare_build()
{
	local list="$1"		# kalua/openwrt-build/mybuild.sh set_build list
	local action

	for action in $list; do {
		log "[START] invoking: '$action'"
		kalua/openwrt-build/mybuild.sh set_build "$action"
		log "[READY] invoking: '$action'"
	} done
}

changedir release
clone "git://nbd.name/openwrt.git"
clone "git://nbd.name/packages.git"
changedir openwrt
clone "git://github.com/bittorf/kalua.git"

mymake defconfig
mymake package/symlinks

#prepare_build "standard kernel.addzram vtunZlibLZOnoSSL b43minimal luci dataretention"
prepare_build "standard kernel.addzram b43minimal dataretention"

mymake defconfig
kalua/openwrt-build/mybuild.sh applymystuff
kalua/openwrt-build/mybuild.sh make

log "please removing everything via 'rm -fR release' if you are ready"

