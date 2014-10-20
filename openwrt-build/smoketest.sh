#!/bin/sh

TYPE="$1"
OPTION="$2"
MYLOG='special_log.txt'

[ -z "$TYPE" ] && {
	echo "Usage: $0 <type> <architecture>"
	echo "       type can be 'kernel' or 'full'"
	echo "       with you can select the kernel-version of which arch's are taken, e.g. '3\.10\.'"

	exit 1
}

log()
{
	logger -s "$0: $1"
	echo "[$( date )] $0: $1" >>"$MYLOG"
}

[ -e 'Config.in' ] || {
	git clone git://nbd.name/openwrt.git
	cd openwrt
}

if [ "$TYPE" = 'full' ]; then
	MAKECOMMAND="-j25"
else
	MAKECOMMAND="-j25 target/linux/compile"
fi

list_architectures()
{
	local with_kernel="$1"		# empty = all

	# target/linux/gemini/Makefile:LINUX_VERSION:=3.10.49 -> gemini
	grep ^"LINUX_VERSION:=${with_kernel}" target/linux/*/Makefile | cut -d'/' -f3
}

clean()
{
	for DIR in bin build_dir staging_dir target; do {
		[ -e "$DIR" ] && {
			log "${ARCH:-init/clean} - du: $( du -sh "$DIR" )"
			rm -fR "$DIR"
		}
	} done
}

for ARCH in $( list_architectures "$OPTION" ); do {
	log "$ARCH - start"
	echo "CONFIG_TARGET_${ARCH}=y" >'.config' && make defconfig

	if make $MAKECOMMAND; then
		log "$ARCH - OK"
		clean
	else
		log "$ARCH - ERROR"
	fi
} done
