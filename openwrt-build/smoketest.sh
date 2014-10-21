#!/bin/sh

# TODO: build always in step: tools/toolchain/kernel/all
# TODO: build specific arch, e.g 'x86 gemini avr32'

TYPE="$1"
OPTION="$2"
MYLOG='/tmp/special_log.txt'

[ -z "$TYPE" ] && {
	echo "Usage: $0 <type> <architecture>"
	echo "       type can be 'kernel' or 'full'"
	echo "       with you can select the kernel-version of which arch's are taken, e.g. '3\.10\.'"

	exit 1
}

log()
{
	local message="$1"
	local prio="$2"

	message="${ARCH:-init/clean} - $message"

	logger -s "$MYLOG: $0: $message"
	[ "$prio" = 'debug' ] || echo "[$( date )] $0: $message" >>"$MYLOG"

	return 0
}

mymake()
{
	local force_cpu="$1"
	local cpu=$(( $(grep -c ^'processor' /proc/cpuinfo) + 1 ))

	[ -n "$force_cpu" ] && cpu="$force_cpu"

	if [ "$TYPE" = 'full' ]; then
		make -j$cpu && return 0
	else
		make -j$cpu tools/install	 || return 1
		log "make ok: tools"
		make -j$cpu toolchain/install	 || return 1
		log "make ok: toolchain"
		make -j$cpu target/linux/compile || return 1
		log "make ok: linux"
#		package/compile
#		package/install
#		target/install
		return 0
		# build_dir/target-mips_34kc_uClibc-0.9.33.2/linux-ar71xx_generic/vmlinux*
	fi

	return 1
}

list_architectures()
{
	local with_kernel="$1"		# empty = all
	local line

	# target/linux/gemini/Makefile:LINUX_VERSION:=3.10.49 -> gemini
	grep ^"LINUX_VERSION:=${with_kernel}" target/linux/*/Makefile | cut -d'/' -f3 | while read line; do {
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

			cd 'openwrt'
			LIST_ARCH="$( list_architectures "$OPTION" )"

			return 0
		;;
	esac

	log "(make a clean copy of 'openwrt-$ARCH')" debug
	cp -R 'openwrt' "openwrt-$ARCH"
	cd "openwrt-$ARCH"

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
		log "ERROR - building again" debug
		mymake '1 V=s' >"${MYLOG}-logfail-$ARCH"

		if [ $? -eq 0 ]; then
			log "OK - after rebuild with -j1"
		else
			log "ERROR"
		fi
	fi
} done

cd ..
rm -fR "openwrt-$ARCH"
