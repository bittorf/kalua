#!/bin/sh

list_options()
{
	echo 'Standard'					# sizecheck

	echo 'Standard,VDS,kalua'			# typical hotel
	echo 'Standard,VDS,USBprinter,kalua'		# roehr30
	echo 'Standard,VDS,BTCminerBFL,kalua'		# ejbw/16
	echo 'Standard,VDS,BigBrother,kalua'		# buero/fenster
	echo 'Standard,VDS,USBaudio,kalua'		# f36stube
	echo 'Standard,VDS,BigBrother,USBaudio,kalua'	# buero/kueche

	echo 'Small'					# sizecheck

	echo 'Small,OLSRd,kalua'
	echo 'Small,BatmanAdv,kalua'
	echo 'Small,OLSRd,BatmanAdv,kalua'

	echo 'Small,VDS,OLSRd,kalua'
	echo 'Small,VDS,BatmanAdv,kalua'
	echo 'Small,VDS,OLSRd,BatmanAdv,kalua'

	echo 'Small,noPPPoE'				# sizecheck
	echo 'Small,noPPPoE,OLSRd,kalua'
	echo 'Small,noPPPoE,BatmanAdv,kalua'
	echo 'Small,noPPPoE,OLSRd,BatmanAdv,kalua'
	echo 'Small,noPPPoE,VDS,OLSRd,kalua'
	echo 'Small,noPPPoE,VDS,BatmanAdv,kalua'
	echo 'Small,noPPPoE,VDS,OLSRd,BatmanAdv,kalua'

#	echo 'Mini'

	# + alles mit LuCIfull
	# Bluetooth
}

list_hw()
{
	$KALUA_DIRNAME/openwrt-build/build.sh --hardware list plain | grep ^"${1:-.}"$
}

stopwatch_start()
{
	read T1 REST </proc/uptime
}

stopwatch_stop()
{
	read T2 REST </proc/uptime
	DURATION=$(( ${T2%.*}${T2#*.} - ${1%.*}${1#*.} ))
	DURATION=$(( $BUILD_DURATION / 100 )).$(( $BUILD_DURATION % 100 ))
	echo "$DURATION"
}

log()
{
	local file='release.txt'

	logger -s "$file : $1"
	echo >>"$file" "$( date ) - $1"
}

if [ -z "$1" ]; then
	echo "Usage: $0 <OpenWrt-Revision> <model> <mode> <server-path>"
	echo " e.g.: $0 'r39455' 'Ubiquiti Bullet M' 'testing' 'root@intercity-vpn.de:/var/www/blubb/firmware'"
	echo " e.g.: $0 'trunk'  ''                  'stable'  'root@intercity-vpn.de:/var/www/blubb/firmware'"
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

for OPT in $( list_options ); do {
	list_hw "$HARDWARE" | while read HW; do {
		stopwatch_start
		log "# $BUILD --hardware \"$HW\" --option \"$OPT\" --openwrt \"$REV\" --release \"$MODE\" \"$DEST\""

		if     $BUILD --hardware  "$HW"  --option  "$OPT"  --openwrt  "$REV"  --release  "$MODE"   "$DEST" ; then
			log "[OK] in $( stopwatch_stop $T1 ) sec"
		else
			log "[FAILED] after $( stopwatch_stop $T1 ) sec"
			# e.g. image too large, so do next
			git checkout master
		fi
	} done
} done
