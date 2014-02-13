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
	echo 'Mini'

	# + alles mit LuCIfull
	# Bluetooth
}

list_hw()
{
	$KALUA_DIRNAME/openwrt-build/build.sh --hardware list plain
}

# kalua/openwrt-build/build.sh      -> kalua
# weimarnetz/openwrt-build/build.sh -> weimarnetz
KALUA_DIRNAME="$( echo "$0" | cut -d'/' -f1 )"
REV="${1:-r39455}"
HARDWARE="${2:-$( list_hw )}"
MODE="${3:-testing}"

for OPT in $( list_options ); do {
	for HW in $HARDWARE; do {
		$KALUA_DIRNAME/openwrt-build/build.sh --hardware "$HW" --option "$OPT" --openwrt "$REV" --release "$MODE"
	} done
} done
