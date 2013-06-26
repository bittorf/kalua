#!/bin/sh

# todo:
# - stick to specific git-revision
# - autodownload .definitions

# arguments e.g.:
# "HARDWARE.Linksys WRT54G:GS:GL" standard kernel.addzram kcmdlinetweak patch:901-minstrel-try-all-rates.patch dataretention nopppoe b43minimal olsrsimple nohttps nonetperf
# "HARDWARE.TP-LINK TL-WR1043ND"  standard kernel.addzram kcmdlinetweak patch:901-minstrel-try-all-rates.patch dataretention

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

if [ -z "$REPONAME" ] || [ -z "$REPOURL" ]; then
        log "please set the variables \$REPONAME and \$REPOURL to appropriate values, e. g. \"weimarnetz\" for REPONAME and \"git://github.com/weimarnetz/weimarnetz.git\" for REPOURL"
        log "\$REPONAME is the name of the directory where you checked out the repository \$REPOURL"
        echo ""
        exit 1
fi

TRUNK=0
case "$@" in
	*"use_trunk"*)
		log "we will be on top of openwrt devopment"
		TRUNK=1
	;;
esac


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
		git stash
		git checkout master
		git pull
		changedir ..
	else
		log "git-cloning from '$repo'"
		git clone "$repo"
	fi
	
	if [ -e ../../$REPONAME/openwrt-config/git_revs ] && [ $TRUNK = 0 ]; then
		. ../../$REPONAME/openwrt-config/git_revs
		case "$repo" in
			*"openwrt"*)
				[ -n $MY_OPENWRT ] && {
					changedir "$dir"
					git branch -D "r$MY_OPENWRT"
					git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$MY_OPENWRT " | cut -d' ' -f2 )" -b r$MY_OPENWRT
					changedir ..
				}
			;;
			*"packages"*)
				[ -n $MY_PACKAGES ] && {
					changedir "$dir"
					git branch -D "r$MY_PACKAGES"
					git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$MY_PACKAGES" | cut -d' ' -f2 )" -b r$MY_PACKAGES
					changedir ..
				}
			;;
		esac
	fi
}

mymake()	# fixme! how to ahve a quiet 'make defconfig'?
{
	log "[START] executing 'make $1 $2 $3'"
	make $1 $2 $3
	log "[READY] executing 'make $1 $2 $3'"
}

prepare_build()		# check possible values via:
{			# $REPONAME/openwrt-build/mybuild.sh set_build list
	local action

	case "$@" in
		*" "*)
			log "list: '$@'"
		;;
	esac

	for action in "$@"; do {
		log "[START] invoking: '$action' from '$@'"

		case "$action" in
			r[0-9]|r[0-9][0-9]|r[0-9][0-9][0-9]|r[0-9][0-9][0-9][0-9]|r[0-9][0-9][0-9][0-9][0-9])
				REV="$( echo "$action" | cut -d'r' -f2 )"
				log "switching to revision r$REV"
				git stash
				git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$REV " | cut -d' ' -f2 )" -b r$REV
				continue
			;;
			"use_trunk")
				continue
			;;
		esac

		$REPONAME/openwrt-build/mybuild.sh set_build "$action"
		log "[READY] invoking: '$action' from '$@'"
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

[ -e "/tmp/apply_profile.code.definitions" ] || {
	log "please make sure, that you have placed you settings in '/tmp/apply_profile.code.definitions'"
	log "otherwise i'll take the community-settings"
	sleep 5
}

changedir release
clone "git://nbd.name/openwrt.git" "$TRUNK"
clone "git://nbd.name/packages.git" "$TRUNK"
changedir openwrt

clone "$REPOURL"
#copy feeds.conf to openwrt directory
cp $REPONAME/openwrt-build/feeds.conf ./

prepare_build "reset_config"
mymake package/symlinks
prepare_build "$@"
mymake defconfig

for SPECIAL in unoptimized kcmdlinetweak; do {
	case "$@" in
		*"$SPECIAL"*)
			prepare_build $SPECIAL
		;;
	esac
} done

$REPONAME/openwrt-build/mybuild.sh applymystuff
$REPONAME/openwrt-build/mybuild.sh make

log "please removing everything via 'rm -fR release' if you are ready"
log "# buildstring: $( show_args "$@" )"

