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

exit 0
# build-test:
#
# - install all deps
# - change to user-account
#
# wget -O openwrt_download_cache.tar http://4.v.weimarnetz.de/1.tar
# tar xf openwrt_download_cache.tar
# mount -t tmpfs -o size=14G,nosuid,nodev,mode=1777 tmpfs /media/cdrom
# git clone git://git.openwrt.org/openwrt.git
# cd openwrt
# ln -s ~/dl dl		# download_cache
#
# rene:
# (make dirclean)

work()
{
	echo "CONFIG_TARGET_${1:-mpc85xx}=y" >.config

	THREADS=$( grep -sc ^processor /proc/cpuinfo )
	THREADS=$(( THREADS + 1 ))

	S0='defconfig'
	S1="tools/install $( test "$(id -u)" = 0 && echo FORCE_UNSAFE_CONFIGURE=1 )"
	S2='toolchain/install'
	S3='target/compile'
	S4='package/compile'
	S5='package/install'
	S6='package/preconfig'
	S7='target/install'
	S8='package/index'
	S9='clean'

	for STEP in "$S0" "$S1" "$S2" "$S3" "$S4" "$S5" "$S6" "$S7" "$S8" "$S9" '' dirclean; do
		COMMAND="make -j$THREADS $STEP"
		echo "real: $COMMAND | $( cat /proc/loadavg ) - space: $( du -sh )"
		/usr/bin/time -f "real %e secs" $COMMAND || break
	done
}

work mpc85xx 2>&1 | tee LOG
# while :;do case "$(cat /proc/loadavg)" in 0.0*) work 2>&1 | tee LOG; break;;*) uptime;sleep 30;; esac; done
grep ^real LOG | while read L; do set -- $L; test "$1" != 'real:' && echo "$L $O" || { shift; O="$*"; }; done

# Comp1 = rene   / KVM: Intel Xeon(R) CPU X5650       @ 2.67GHz / 24 threads
# Comp2 = max    / AMD Phenom(tm) II X4 955 Processor @ 3.8GHz  /  4 threads
# Comp3 = martin / Intel(R) Xeon(R) CPU E5-2620 v2    @ 2.10GHz / 24 threads
# Comp4 = holm   / AMD Phenom(tm) II X4 940 Processor @ 3.0GHz  /  4 threads
# Comp5 = gcc20  / Intel(R) Xeon(R) CPU X5670         @ 2.93GHz / 24 threads

### measure time = tools/install + toolchain/install + last make
### work mpc85xx >LOG 2>&1 - needs 7.9GB tmpfs
# Comp1 ::: 987 sec
real   1.34 secs make -j25 defconfig
real 330.28 secs make -j25 tools/install FORCE_UNSAFE_CONFIGURE=1
real 520.04 secs make -j25 toolchain/install
real  30.48 secs make -j25 target/compile
real 101.95 secs make -j25 package/compile
real   4.41 secs make -j25 package/install
real   1.69 secs make -j25 package/preconfig
real  39.78 secs make -j25 target/install
real   2.94 secs make -j25 package/index
real   1.91 secs make -j25 clean
real 147.28 secs make -j25

# Comp2 ::: 1692 sec
real  19.08 secs make -j5 defconfig
real 473.42 secs make -j5 tools/install FORCE_UNSAFE_CONFIGURE=1
real 944.93 secs make -j5 toolchain/install
real  40.32 secs make -j5 target/compile
real 158.78 secs make -j5 package/compile
real   5.50 secs make -j5 package/install
real   1.80 secs make -j5 package/preconfig
real  86.57 secs make -j5 target/install
real   3.33 secs make -j5 package/index
real   1.84 secs make -j5 clean
real 275.73 secs make -j5

# Comp3 ::: 1160 sec 
real  58.62 secs make -j25 defconfig
real 434.66 secs make -j25 tools/install FORCE_UNSAFE_CONFIGURE=1
real 550.35 secs make -j25 toolchain/install
real  45.20 secs make -j25 target/compile
real 130.06 secs make -j25 package/compile
real  12.03 secs make -j25 package/install
real   6.72 secs make -j25 package/preconfig
real  49.15 secs make -j25 target/install
real   8.85 secs make -j25 package/index
real   6.47 secs make -j25 clean
real 176.55 secs make -j25

# Comp4 ::: 1749 sec
real   16.36 secs make -j5 defconfig | 0.00 0.01 0.54 1/228 3717 - space: 523M .
real  467.24 secs make -j5 tools/install | 0.29 0.08 0.55 1/229 5900 - space: 541M .
real 1000.37 secs make -j5 toolchain/install | 4.75 3.66 2.08 1/228 20690 - space: 1.4G .
real   39.98 secs make -j5 target/compile | 2.81 4.13 3.64 1/228 14215 - space: 6.6G .
real  168.18 secs make -j5 package/compile | 2.84 3.95 3.60 1/228 26564 - space: 7.3G .
real    4.00 secs make -j5 package/install | 5.00 4.48 3.86 1/228 26394 - space: 7.8G .
real    1.68 secs make -j5 package/preconfig | 4.68 4.42 3.85 1/228 28630 - space: 7.8G .
real   91.39 secs make -j5 target/install | 4.68 4.42 3.85 1/228 28794 - space: 7.8G .
real    2.77 secs make -j5 package/index | 4.60 4.49 3.93 1/228 7755 - space: 8.1G .
real    2.96 secs make -j5 clean | 4.60 4.49 3.93 1/228 9217 - space: 8.1G .
real  282.12 secs make -j5 		| 4.31 4.44 3.91 1/228 9346 - space: 6.7G .

# Comp5 ::: 1294 sec
real 21.76 secs make -j9 defconfig | 2.51 2.25 1.98 3/327 18082 - space: 190M .
real 368.67 secs make -j9 tools/install | 2.79 2.33 2.01 3/326 20607 - space: 209M .
real 726.90 secs make -j9 toolchain/install | 8.53 7.03 4.23 3/329 6168 - space: 1.1G .
real 38.63 secs make -j9 target/compile | 7.13 9.03 7.28 2/327 31159 - space: 6.3G .
real 118.47 secs make -j9 package/compile | 6.01 8.31 7.13 2/327 13646 - space: 7.0G .
real 2.86 secs make -j9 package/install | 8.77 8.87 7.50 2/333 15134 - space: 7.5G .
real 1.17 secs make -j9 package/preconfig | 8.77 8.87 7.50 2/329 17385 - space: 7.5G .
real 62.56 secs make -j9 target/install | 8.22 8.76 7.47 2/332 17553 - space: 7.5G .
real 1.87 secs make -j9 package/index | 9.04 9.01 7.64 2/329 29413 - space: 7.8G .
real 2.12 secs make -j9 clean | 8.39 8.87 7.60 2/330 30901 - space: 7.8G .
real 200.29 secs make -j9 | 8.39 8.87 7.60 2/330 31030 - space: 6.4G .



# work ar71xx >LOG 2>&1 - needs 12GB tmpfs - Comp1
real  16.28 secs make -j25 defconfig
real 336.66 secs make -j25 tools/install FORCE_UNSAFE_CONFIGURE=1
real 475.08 secs make -j25 toolchain/install
real  43.54 secs make -j25 target/compile
real 102.44 secs make -j25 package/compile
real   4.53 secs make -j25 package/install
real   1.72 secs make -j25 package/preconfig
real 323.67 secs make -j25 target/install
real   2.99 secs make -j25 package/index
real   2.33 secs make -j25 clean
real 449.96 secs make -j25

# work uml >LOG 2>&1 - needs 8.5GB tmpfs - Comp1
real 338.06 secs make -j25 tools/install FORCE_UNSAFE_CONFIGURE=1
real 659.34 secs make -j25 toolchain/install
real  32.56 secs make -j25 target/compile
real 105.08 secs make -j25 package/compile
real   4.33 secs make -j25 package/install
real   1.69 secs make -j25 package/preconfig
real  38.49 secs make -j25 target/install
real   2.81 secs make -j25 package/index
real   1.99 secs make -j25 clean
real 143.58 secs make -j25

# work brcm47xx >LOG 2>&1 - needs 7.8GB tmpfs - Comp1
real  16.51 secs make -j25 defconfig
real 327.94 secs make -j25 tools/install FORCE_UNSAFE_CONFIGURE=1
real 455.14 secs make -j25 toolchain/install
real  35.40 secs make -j25 target/compile
real 100.31 secs make -j25 package/compile
real   4.70 secs make -j25 package/install
real   1.67 secs make -j25 package/preconfig
real 43.81 secs make -j25 target/install
real   2.95 secs make -j25 package/index
real   1.89 secs make -j25 clean
real 160.63 secs make -j25
