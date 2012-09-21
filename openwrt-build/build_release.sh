#!/bin/sh

# todo:
# - stick to specific git-revision
# - autodownload .definitions

# arguments e.g.:
# "HARDWARE.Linksys WRT54G:GS:GL" standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention nopppoe b43minimal olsrsimple nohttps nonetperf
# "HARDWARE.TP-LINK TL-WR1043ND"  standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention

log()
{
	logger -s "$( date ): [$( pwd )]: $0: $1"
}

[ -z "$1" ] && {
	log "Usage: $0 <buildstring>"
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

mymake()	# fixme! how to ahve a quiet 'make defconfig'?
{
	log "[START] executing 'make $1 $2 $3'"
	make $1 $2 $3
	log "[READY] executing 'make $1 $2 $3'"
}

prepare_build()
{
	local list="$1"		# kalua/openwrt-build/mybuild.sh set_build list
	local action

	case "$list" in
		*" "*)
			log "list: '$list'"
		;;
	esac

	for action in $list; do {
		log "[START] invoking: '$action' from '$list'"
		kalua/openwrt-build/mybuild.sh set_build "$action"
		log "[READY] invoking: '$action' from '$list'"
	} done
}

show_args()
{
	local word

	for word in "$@"; do {
		case "$word" in
			*" "*)
				echo -n " '$word'"
			;;
			*)
				echo -n " $word"
			;;
		esac
	} done
}

changedir release
clone "git://nbd.name/openwrt.git"
clone "git://nbd.name/packages.git"
changedir openwrt
clone "git://github.com/bittorf/kalua.git"

prepare_build "reset_config"
mymake package/symlinks
prepare_build "$@"

kalua/openwrt-build/mybuild.sh applymystuff
kalua/openwrt-build/mybuild.sh make

log "please removing everything via 'rm -fR release' if you are ready"
log "# buildstring: $( show_args "$@" )"

