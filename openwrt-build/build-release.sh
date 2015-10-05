#!/bin/sh

list_options()		# disable e.g. USB-builds for router without USB or images that are too big?
{
#	echo 'Standard'					# sizecheck

	echo 'Standard,VDS,kalua'			# typical hotel / 8mb-flash
#	echo 'Standard,VDS,USBprinter,kalua'		# roehr30
#	echo 'Standard,VDS,BTCminerBFL,kalua'		# ejbw/16
#	echo 'Standard,VDS,BigBrother,kalua'		# buero/fenster
#	echo 'Standard,VDS,USBaudio,kalua'		# f36stube
#	echo 'Standard,VDS,BigBrother,USBaudio,kalua'	# buero/kueche
#
#	echo 'Small'					# sizecheck
#
#	echo 'Small,OLSRd,kalua'
#	echo 'Small,BatmanAdv,kalua'
#	echo 'Small,OLSRd,BatmanAdv,kalua'
#
#	echo 'Small,VDS,OLSRd,kalua'
#	echo 'Small,VDS,BatmanAdv,kalua'
#	echo 'Small,VDS,OLSRd,BatmanAdv,kalua'
#
#	echo 'Small,noPPPoE'				# sizecheck
	echo 'Small,noPPPoE,OLSRd,kalua'		# typical hotel / 4mb-flash
#	echo 'Small,noPPPoE,BatmanAdv,kalua'
#	echo 'Small,noPPPoE,OLSRd,BatmanAdv,kalua'
#	echo 'Small,noPPPoE,VDS,OLSRd,kalua'
#	echo 'Small,noPPPoE,VDS,BatmanAdv,kalua'
#	echo 'Small,noPPPoE,VDS,OLSRd,BatmanAdv,kalua'

#	echo 'Mini'

	# + alles mit LuCIfull
	# Bluetooth
	# noWiFi
}

list_hw()
{
	local line

	case "$1" in
		'hash')
			$KALUA_DIRNAME/openwrt-build/build.sh --hardware list plain | while read -r line; do {
				[ "$( echo -n "$line" | md5sum | cut -d' ' -f1 )" = "$2" ] && {
					echo "$line"
					return
				}
			} done
		;;
		''|'all')
			$KALUA_DIRNAME/openwrt-build/build.sh --hardware list plain
		;;
		*)
			$KALUA_DIRNAME/openwrt-build/build.sh --hardware list plain | grep ^"${1:-.}"$ || {
				log "list_hw() hardware '$1' not found"
				exit 1
			}
		;;
	esac
}

stopwatch()
{
	if [ -z "$2" ]; then
		read -r T1 REST </proc/uptime
	else
		T1="$2"
		read -r T2 REST </proc/uptime
		DURATION=$(( ${T2%.*}${T2#*.} - ${T1%.*}${T1#*.} ))
		DURATION=$(( DURATION / 100 )).$(( DURATION % 100 ))

		echo "$DURATION"
	fi
}

log()
{
	local file='release.txt'

	logger -s "$file : $1"
	echo >>"$file" "$1"
}

show_progress()
{
	[ -z "$TIME_START" ] && TIME_START="$( date )"
	[ -z "$UNIXTIME_START" ] && UNIXTIME_START="$( date +%s )"

	TIME_SPENDED=$(( $(date +%s) - UNIXTIME_START ))
	BUILD_DONE=$(( BUILD_GOOD + BUILD_BAD + 1 ))
	TIME_PER_IMAGE=$(( TIME_SPENDED / BUILD_DONE ))
	BUILD_PENDING=$(( BUILD_ALL - BUILD_DONE ))
	TIME_LEFT=$(( (TIME_SPENDED * BUILD_PENDING) / 60 ))		# mins
	BUILD_PROGRESS="[images build: $BUILD_DONE/$BUILD_ALL -> $BUILD_PENDING left - $TIME_PER_IMAGE sec/image - $TIME_LEFT mins left]"

	log "# $BUILD_PROGRESS"
}

if [ -z "$1" ]; then
	echo "Usage: $0 <OpenWrt-Revision> <model> <mode> <server-path>"
	echo " e.g.: $0 'r39455' 'Ubiquiti Bullet M5' 'testing' 'root@intercity-vpn.de:/var/www/blubb/firmware'"
	echo " e.g.: $0 'trunk'  'all'               'stable'  'root@intercity-vpn.de:/var/www/blubb/firmware'"
	exit 1
else
	REV="$1"
	HARDWARE="$2"
	MODE="$3"
	DEST="$4"
fi

# kalua/openwrt-build/build.sh      -> kalua
# weimarnetz/openwrt-build/build.sh -> weimarnetz
KALUA_DIRNAME="$( echo "$0" | cut -d'/' -f1 )"
BUILD="$KALUA_DIRNAME/openwrt-build/build.sh"
HW_LIST="$( list_hw "$HARDWARE" | while read -r LINE; do echo -n "$LINE" | md5sum | cut -d' ' -f1; done )"

BUILD_GOOD=0
BUILD_BAD=0
BUILD_ALL=0

for HW in $HW_LIST; do {
	for OPT in $( list_options ); do {
		BUILD_ALL=$(( BUILD_ALL + 1 ))
	} done
} done

for HW in $HW_LIST; do {
	HW="$( list_hw hash "$HW" )"	# dirty trick because of spaces in list members

	for OPT in $( list_options ); do {
		stopwatch start
		show_progress
		log "# $BUILD --quiet --hardware '$HW' --usecase '$OPT' --openwrt $REV --release '$MODE' '$DEST'"

		if     $BUILD --quiet --hardware "$HW" --usecase "$OPT" --openwrt $REV --release "$MODE" "$DEST" ; then
			BUILD_GOOD=$(( BUILD_GOOD + 1 ))
			log "[OK] in $( stopwatch stop "$T1" ) sec"
		else
			BUILD_BAD=$(( BUILD_BAD + 1 ))
			log "[FAILED] after $( stopwatch stop "$T1" ) sec"
			# e.g. image too large - ignore and do next
			git checkout master
		fi
	} done
} done

log "START: $TIME_START"
log "READY: $( date )"
log "good: $BUILD_GOOD bad: $BUILD_BAD"
