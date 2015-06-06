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
		log "we will be on top of openwrt development"
		TRUNK=1
	;;
	*"use_bb1407"*)
		log "we will use the 14.07 barrier breaker stable version"
		TRUNK=bb1407
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
		git pull || {
            log "error pulling repo"
            exit 1
        }
		changedir ..
	else
		log "git-cloning from '$repo'"
		git clone "$repo" || { 
           log "error cloning repo" 
           exit 1
       }
	fi
	
	if [ -e "../../$REPONAME/openwrt-config/git_revs" ] && [ $TRUNK = 0 ]; then
		. "../../$REPONAME/openwrt-config/git_revs"
		case "$repo" in
			*"openwrt"*)
				[ -n "$MY_OPENWRT" ] && {
					changedir "$dir"
					git branch -D "r$MY_OPENWRT"
					git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$MY_OPENWRT " | cut -d' ' -f2 )" -b r$MY_OPENWRT || {
                       log "error during git checkout"
                       exit 1
                    }
					changedir ..
				}
			;;
			*"packages"*)
				[ -n "$MY_PACKAGES" ] && {
					changedir "$dir"
					git branch -D "r$MY_PACKAGES"
					git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$MY_PACKAGES" | cut -d' ' -f2 )" -b r$MY_PACKAGES || {
                       log "error during git checkout" 
                       exit 1
                   }
					changedir ..
				}
			;;
		esac
	fi
}

# print a json file with openwrt and weimarnetz revision, we assume to be in the openwrt directory
print_revisions()
{
	OPENWRT_REV="$( ./scripts/getver.sh )"
	KALUA_REV="$(  cat package/base-files/files/etc/variables_fff+ |grep FFF_PLUS|tr -d '[:space:]'|cut -d '=' -f 2|cut -d '#' -f 1)"	
	echo "{\"OPENWRT_REV\":\"$OPENWRT_REV\",\"KALUA_REV\":\"$KALUA_REV\"}" > "bin/revisions.json"
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
				git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$REV " | cut -d' ' -f2 )" -b r$REV || {
                log "error while git checkout" 
                exit 1
            }
				continue
			;;
			*"use_"*)
				continue
			;;
		esac

		"$REPONAME/openwrt-build/mybuild.sh" set_build "$action"
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
if [ "$TRUNK" = "bb1407" ]; then
	clone "git://git.openwrt.org/14.07/openwrt.git" "$TRUNK"
else
	clone "git://nbd.name/openwrt.git" "$TRUNK"
	clone "git://nbd.name/packages.git" "$TRUNK"
fi
changedir openwrt

clone "$REPOURL"
#copy feeds.conf to openwrt directory
if [ "$TRUNK" = "bb1407" ]; then
	cp "$REPONAME/openwrt-build/feeds.conf.1407" ./feeds.conf
else
	cp "$REPONAME/openwrt-build/feeds.conf" ./
fi

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

#$REPONAME/openwrt-build/mybuild.sh applymystuff
"$REPONAME/openwrt-build/mybuild.sh" make
print_revisions

log "please removing everything via 'rm -fR release' if you are ready"
log "# buildstring: $( show_args "$@" )"

