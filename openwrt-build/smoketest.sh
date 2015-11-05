#!/bin/sh

# TODO: build in ramdisc?
# TODO: make tools/install - only ONCE? (for all platforms) - how to detect if it was build already?
# TODO: generate HTML-page
# TODO: report: if NO/$number of error occurs, write it when finished
# TODO: mymake: if it fails only build the last step with -j1 not everything before

TYPE="$1"
OPTION="$2"
MYLOG='/tmp/special_log.txt'

[ -z "$TYPE" ] && {
	echo "Usage: $0 <type> <option>"
	echo "       type can be 'tools', 'toolchain', 'kernel' or 'full'"
	echo "       <option> can be the kernel-version of which arch's are taken,"
	echo "       e.g. '3\.10\.' - this builds for all archs which are at 3.10 or"
	echo "       e.g. 'ar71xx x86' which directly builds these architectures"
	exit 1
}

log()
{
	local message="$1"
	local prio="$2"

	message="${ARCH:-init/clean} - r${OPENWRT_REV:-?} - $message"

	logger -s "$MYLOG: $0: $message"
	[ "$prio" = 'debug' ] || echo "[$( date )] $0: $message" >>"$MYLOG"

	return 0
}

openwrt_revision_get()
{
	git log -1 | fgrep 'git-svn-id:' | cut -d'@' -f2 | cut -d' ' -f1
}

mymake()
{
	local force_cpu="$1"
	local cpu=$(( $(grep -c ^'processor' /proc/cpuinfo) + 1 ))

	[ -n "$force_cpu" ] && cpu="$force_cpu"
	log "mymake() using parallel-build: -j$cpu"

	make -j$cpu tools/install	 || return 1
	log "make ok: tools"
	[ "$TYPE" = 'tools' ] && return 0

	make -j$cpu toolchain/install	 || return 1
	log "make ok: toolchain"
	[ "$TYPE" = 'toolchain' ] && return 0

	make -j$cpu target/linux/compile || return 1
	# now in e.g.: build_dir/target-mips_34kc_uClibc-0.9.33.2/linux-ar71xx_generic/vmlinux
	log "make ok: linux"
	[ "$TYPE" = 'kernel' ] && return 0

	make -j$cpu package/compile	|| return 1
	log "make ok: package/compile"
	make -j$cpu package/install	|| return 1
	log "make ok: package/install"
	make -j$cpu target/install	|| return 1
	log "make ok: target/install"
}

list_architectures()
{
	local with_kernel="$1"		# <empty> = all
	local archlist line

	for line in $with_kernel; do {
		if [ -e "target/linux/$line/Makefile" ]; then
			archlist="$archlist $line"
		else
			archlist=
			break
		fi
	} done
	[ -n "$archlist" ] && {
		echo "$archlist"
		return 0
	}

	# target/linux/gemini/Makefile:LINUX_VERSION:=3.10.49 -> gemini
	grep ^"LINUX_VERSION:=${with_kernel}" target/linux/*/Makefile | cut -d'/' -f3 | while read -r line; do {
		echo -n "$line "
	} done

	# since r43047
	# KERNEL_PATCHVER:=3.10
	grep ^"KERNEL_PATCHVER:=${with_kernel}" target/linux/*/Makefile | cut -d'/' -f3 | while read -r line; do {
		echo -n "$line "
	} done
}

clean()
{
	for DIR in bin build_dir staging_dir target toolchain; do {
		[ -e "$DIR" ] && {
			log "discusage: $( du -sh "$DIR" )" debug
			rm -fR "$DIR"
		}
	} done
}

defconfig()
{
	local base="$( basename "$(pwd)" )"
	local url='git://nbd.name/openwrt.git'
	local cachedir='openwrt_download_cache'

	log "defconfig() base: '$base' pwd: '$( pwd )'" debug

	case "$base" in
		'openwrt')
			cd ..
		;;
		'openwrt-'*)
			# e.g. openwrt-x86
			cd ..
			log "(removing old dir '$base')" debug
			rm -fR "$base"
		;;
		*)
			[ -d 'openwrt' ] || {
				log "fresh checkout of '$url'"
				git clone "$url"
			}

			log "TYPE: $TYPE OPTION: $OPTION - all downloads are going into '$( pwd )/$cachedir'"
			mkdir -p "$cachedir"

			cd 'openwrt' || return
			LIST_ARCH="$( list_architectures "$OPTION" )"
#			OPENWRT_REV="$( openwrt_revision_get )"

			return 0
		;;
	esac

	log "(make a clean copy of 'openwrt-$ARCH')" debug
	cp -R 'openwrt' "openwrt-$ARCH"
	cd "openwrt-$ARCH" || return

	[ -d 'dl' ] && {
		# only remove if no symbolic link:
		[ -h 'dl' ] || rm -fR 'dl'
	}
	ln -s ../$cachedir 'dl'

	log "starting in '$( pwd )' (out of '$LIST_ARCH')"
	echo "CONFIG_TARGET_${ARCH}=y" >'.config'
	make defconfig
}

defconfig
for ARCH in $LIST_ARCH; do {
	defconfig

	if mymake; then
		log "OK"
		clean
	else
		log "ERROR - building again with -j1" debug

		if mymake '1 V=s' >"${MYLOG}-logfail-$ARCH"; then
			log "build with -j1: OK"
			rm "${MYLOG}-logfail-$ARCH"
		else
			log "ERROR - even with -j1 - see: ${MYLOG}-logfail-$ARCH"
		fi
	fi
} done

cd ..
rm -fR "openwrt-$ARCH"
