#!/bin/sh

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
	logger -s "$MYLOG: $0: $1"
	echo "[$( date )] $0: $1" >>"$MYLOG"
}

CPU=$(( $(grep -c ^'processor' /proc/cpuinfo) + 1 ))
if [ "$TYPE" = 'full' ]; then
	MAKECOMMAND="-j$CPU"
else
	MAKECOMMAND="-j$CPU target/linux/compile"
fi

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
			log "${ARCH:-init/clean} - du: $( du -sh "$DIR" )"
			rm -fR "$DIR"
		}
	} done
}

defconfig()
{
	local base="$( basename "$(pwd)" )"
	local url='git://nbd.name/openwrt.git'

	case "$base" in
		'openwrt')
		;;
		'openwrt'*)
			log "(removing old dir '$base')"
			rm -fR "$base"
		;;
		*)
			log "fresh checkout of '$url'"
			git clone "$url"

			cd openwrt
			LIST_ARCH="$( list_architectures "$OPTION" )"

			return 0
		;;
	esac

	cd ..
	log "(make a clean copy of 'openwrt-$ARCH')"
	cp -v 'openwrt' "$openwrt-$ARCH"
	cd "$openwrt-$ARCH"

	log "$ARCH - starting with '$MAKECOMMAND' (out of '$LIST_ARCH')"
	echo "CONFIG_TARGET_${ARCH}=y" >'.config'
	make defconfig
}

defconfig
for ARCH in $LIST_ARCH; do {
	defconfig

	if make $MAKECOMMAND; then
		log "$ARCH - OK"
		clean
	else
		log "$ARCH - ERROR"
	fi
} done
