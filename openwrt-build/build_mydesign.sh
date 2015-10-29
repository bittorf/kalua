#!/bin/sh

# func_help ()
# func_defs ()
# func_download_ffkit ()
# func_remove_trash_from_kit ()
# func_update_version_counter () {
# func_apply_own_files_to_ffkit ()
# func_build_images ()
# func_addinfo ()

# ToDo:
# - $KERNEL_VERSION ist an vielen Stellen noch hardgecodet
# - Changelog

WGETERR=

STARTTIME_DATE="$( date )"
STARTTIME_UNIX="$( date +%s )"

# normal workflow for upload changes:
# - make same changes on a router
# - tar czf $PROJECT.tgz $LIST_MY_FILES /www/changelog.txt
# - scp_upload '$PROJECT.tgz' to user@gitserver:/tmp
# - cronjob checks for $PROJECT.tgz and commits with the upper line of /www/changelog.txt
# 
# normal workflow for building firmware-image:
# - URL of tarball
# - URL of 
#


func_help ()
{
	echo "Usage: $0 ( clean | start | adblock <network> <version> | design <network> <version> | settings <network> <version> | checkin_tarball file.tar comment.txt )"
}

func_defs ()
{
	func_addinfo remove

#	local DATENKISTE="www.datenkiste.org"
	local DATENKISTE="10.63.2.38"

	FF_LANG="de"
	FF_VERSION="1.6.37"
	CODENAME="26c3"

#	URL_PACKAGES="http://intercity-vpn.de/firmware/broadcom/packages/2.4.30/essential"
#	URL_PACKAGES="http://ipkg.openwireless.ch/freifunk/packages"
#	URL_PACKAGES="http://download.berlin.freifunk.net/ipkg/packages"
#	URL_PACKAGES="http://download-master.berlin.freifunk.net/ipkg/packages"
#	URL_PACKAGES="http://intercity-vpn.de/ffkit/packages"
	URL_PACKAGES="http://intercity-vpn.de/firmware/broadcom/packages/2.4.30/full/"

#	URL_FF="http://unimos.net/ipkg"
#	URL_FF="http://download.berlin.freifunk.net/ipkg"
#	URL_FF="http://download-master.berlin.freifunk.net/ipkg"
	URL_FF="http://intercity-vpn.de/ffkit"

	URL_FF_KIT="$URL_FF/_kit/freifunk-openwrt-kit-${FF_VERSION}-${FF_LANG}.tar.gz"
	URL_FF_IPT="$URL_FF/openwrt-iptables-so-freifunk-${FF_VERSION}.tar.bz2"
	URL_FF_KMD="$URL_FF/openwrt-kmodules-freifunk-${FF_VERSION}.tar.bz2"

#	URL_FFF_TARBALL="http://$DATENKISTE/cgi-bin/gitweb.cgi?p=fff;a=snapshot;h=refs/heads/master;sf=tgz"			# new
#	URL_FFF_TARBALL="https://github.com/bittorf/kalua/tarball/bc8955ab9bbf8269d33ba04622d7006acda45752"
	URL_FFF_TARBALL="https://github.com/bittorf/kalua/tarball/master"

	PATH_BUILD="build"
	PATH_FW="firmware"

	UPLOAD_TARBALL="root@intercity-vpn.de:/var/www/firmware/testing"
	UPLOAD_IMAGE_TESTING="root@intercity-vpn.de:/var/www/firmware/testing"

	[ ! -e "$PATH_BUILD" ] && mkdir "$PATH_BUILD"
	[ ! -e "$PATH_FW" ]    && mkdir "$PATH_FW"

	DATE="$(LANG=C date +%d%b%Y-%Huhr%M)"
	UNIX="$(( $(date +%s) / 3600))"

	echo "Build-Date: $UNIX"

	SVN_VERSION_NOW="000"
}

func_download_ffkit ()
{
	if [ ! -e "$PATH_BUILD/kit-${FF_VERSION}.tgz" ] || [ "$( stat -c %s "$PATH_BUILD/kit-${FF_VERSION}.tgz" )" = 0 ]; then
		func_addinfo remove
		rm -fR   "$PATH_BUILD"
		mkdir -p "$PATH_BUILD"
		wget -O "$PATH_BUILD/kit-${FF_VERSION}.tgz" "$URL_FF_KIT" 	|| {
			WGETERR="$WGETERR $URL_FF_KIT"
			echo "downloading KIT ('$URL_FF_KIT' -> '$PATH_BUILD/kit-${FF_VERSION}.tgz') failed"
			rm "$PATH_BUILD/kit-${FF_VERSION}.tgz"
			exit
		}

		wget -qO "$PATH_BUILD/iptables-${FF_VERSION}.tgz" "$URL_FF_IPT" || echo "downloading iptables-stuff failed" && exit
		wget -qO "$PATH_BUILD/kmod-${FF_VERSION}.tgz" "$URL_FF_KMD" 	|| echo "downloading kernelmods failed" && exit
	fi
}

func_remove_trash_from_kit ()
{
	[ -e "etc/init.d/S51crond" ] 		&& rm -f etc/init.d/S51crond
	[ -e "etc/init.d/S45firewall.orig" ] 	&& rm -f etc/init.d/S45firewall.orig
	[ -e "etc/init.d/S60rdate" ]		&& rm -f etc/init.d/S60rdate

	[ -e "usr/bin/dropbearmulti" ]		&& rm -f usr/bin/dropbearmulti		# dropbear-related
	[ -e "usr/lib/ipkg/info/dropbear.list" ] && rm -f usr/lib/ipkg/info/dropbear.list
	local LINES="$( cat usr/lib/ipkg/status | wc -l )"
	head -n $(( $LINES - 5 )) usr/lib/ipkg/status >usr/lib/ipkg/status_temp
	mv usr/lib/ipkg/status_temp usr/lib/ipkg/status
	touch usr/bin/dropbear					# /bin/firstboot needs this
}

func_update_version_counter ()
{
	local VARFILE="etc/variables_fff+"

        cat "$VARFILE" |
	 grep -v ^FFF_PLUS_VERSION= |
	  grep -v ^FFF_VERSION= >${VARFILE}.tmp

	cat >>"${VARFILE}.tmp" <<EOF
FFF_PLUS_VERSION="$UNIX"	# $DATE, SVN-$SVN_VERSION_NOW
FFF_VERSION="$FF_VERSION"		# http://download.berlin.freifunk.net/ipkg/
EOF

	mv "${VARFILE}.tmp" "$VARFILE"
}


func_apply_own_files_to_ffkit ()
{
	local build_option="$1"

	logger -s "func_apply_own_files_to_ffkit: build_option = '$build_option'"

	func_download_ffkit
	
	cd "$PATH_BUILD"				&& echo "entered '$PATH_BUILD'"
	mkdir -p newtar_$$
	cd newtar_$$

	wget --no-check-certificate -qO "tarball.tgz" "$URL_FFF_TARBALL" || {
		echo "downloading own tarball ("$URL_FFF_TARBALL") failed"
		exit
	}

	tar xzf tarball.tgz				&& echo "decompressed own GIT-tar.gz"
	rm tarball.tgz					&& echo "deleted tar.gz"

	echo "hier sollte ein DIR fff oder bittorf-kalua-* zu sehen sein:"
	echo
	ls -l
	sleep 3

	[ -d "fff" ] && {
		mv fff* fff
	}

	[ -d bittorf-kalua-* ] && {
		mv bittorf-kalua-* fff
	}

	cd fff

	func_update_version_counter				&& echo "updated version counter ('$FF_VERSION' / '$UNIX' / '${SVN_VERSION:=0}')"
	tar --owner=root --group=root -czf ../../tarball.tgz *	&& echo "generated new tar.gz"
	cd ..
	cd ..
	rm -fR newtar_$$

	func_addinfo "tarball.tgz"
	for ARCH in broadcom ar71xx brcm63xx brcm47xx; do {

		echo "scp tarball.tgz root@intercity-vpn.de:/var/www/firmware/$ARCH/images/testing/"

		while ! scp tarball.tgz root@intercity-vpn.de:/var/www/firmware/$ARCH/images/testing/ ;do {
			sleep 3
		} done

		while ! scp /tmp/info.txt root@intercity-vpn.de:/var/www/firmware/$ARCH/images/testing/ ;do {
			sleep 3
		} done

	} done

	rm -fR "freifunk-openwrt-kit-${FF_VERSION}-de"  || echo "could not delete old kit directory"	# directory always fresh
	tar xzf "kit-${FF_VERSION}.tgz"			&& echo "decompressed fresh kit"
	cd "freifunk-openwrt-kit-${FF_VERSION}-de"	&& echo "entered kit dir"
	
	KERNEL_VERSION="$( ls -1 | sed -n '/[0-9]\.[0-9]\.[0-9]*/p' )"

	mkdir fff
	cd fff
	tar xzf "../root.tgz"				&& echo "decompressed rootfs"
	du -s

	tar xzf "../../tarball.tgz"			&& echo "decompressed own tarball over kit"

	logger -s "enforced profile: $build_option"
	[ -n "$build_option" ] && {
		logger -s "enforced profile: $build_option"

		sed -i "s/#		PROFILE_SAFED=\"example_mesh\"/		PROFILE_SAFED=$build_option/" etc/kalua/profile
		sed -i 's/#		_nvram set/		_nvram set/'	etc/kalua/profile
		sed -i 's/#		uci get/		uci get/'	etc/kalua/profile
		sed -i 's/#		return 1/		return 1/'	etc/kalua/profile

		sed -n '21,28p' etc/kalua/profile
		logger -s "ok? (waiting 10 sec)"
		sleep 10
	}

	func_remove_trash_from_kit			&& echo "deleted some stuff"
	du -s

	cp ../root.tgz ../root_original.tgz
	ls -l   ../root.tgz				&& echo "this was die rootfs"
	tar czf ../root.tgz *				&& echo "created new rootfs with own files"
	ls -l   ../root.tgz				&& echo "this was the new rootfs"
	cd ..						

	rm -fR fff/					|| echo "could not remove my tempdir, now building images"

	func_build_images "$build_option"
}

func_build_images ()
{
	local build_option="$1"		# example_mesh
	local filename_extension

	[ -n "$build_option" ] && {
		filename_extension="_profile=$build_option"
		logger -s "adding this to each filename: $filename_extension"
	}

	local DESC="fff_plus-${CODENAME}-${SVN_VERSION_NOW}-${DATE}"
	local FILE="../../firmware/$DESC"
	local CRC

	mkdir -p packages				&& echo "made a 'packages'-dir"

	./gen-openwrt -v "${DESC}" -o "${FILE}.bin" trx
	func_addinfo "${FILE}.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=BROADCOM.bin"

	./gen-openwrt -v "${DESC}" -o "${FILE}.wrt.bin" g
	func_addinfo "${FILE}.wrt.bin" "linux=${KERNEL_VERSION}_format=WRT_wifidriver=BROADCOM.bin"

	cd packages
	wget "$URL_PACKAGES/wl-adv_1.1_mipsel.ipk" || WGETERR="$WGETERR wl-adv1.1"
	cd ..
	./gen-openwrt -v "${DESC}-wlfull" -o "${FILE}.wlfull.bin" trx
	func_addinfo "${FILE}.wlfull.bin" "linux=${KERNEL_VERSION}_format=WRT_wifidriver=BROADCOMFULL.bin"

	cd packages
	wget "$URL_PACKAGES/freifunk-pppoecd-de_1.6.36_mipsel.ipk" || WGETERR="$WGETERR pppoecd"
	cd ..
	./gen-openwrt -v "${DESC}-pppoe-wlfull" -o "${FILE}.pppoe.wlfull.bin" trx
	func_addinfo "${FILE}.pppoe.wlfull.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=BROADCOMFULL_opt=PPPOE.bin"

	cd packages
	rm wl-adv_1.1_mipsel.ipk
	cd ..
	./gen-openwrt -v "${DESC}-pppoe" -o "${FILE}.pppoe.bin" trx
	func_addinfo "${FILE}.pppoe.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=BROADCOM_opt=PPPOE.bin"

	cd packages
	wget "$URL_PACKAGES/iwlib_28.pre7-1_mipsel.ipk"				|| WGETERR="$WGETERR iwlib"
	wget "$URL_PACKAGES/wireless-tools_28.pre7-1_mipsel.ipk"		|| WGETERR="$WGETERR wireless-tools"
	wget "$URL_PACKAGES/madwifi-tools_r3314-8_mipsel.ipk"			|| WGETERR="$WGETERR madwifi-tools"
	wget "$URL_PACKAGES/kmod-madwifi_2.4.30brcm+r3314-8_mipsel.ipk"		|| WGETERR="$WGETERR kmod-madwifi"
	cd ..

	mkdir fff
	cd fff
	tar xzf ../root.tgz				|| {
		echo "erneutes entpacken des rootfs hat nicht geklappt"
		exit
	}

	rm usr/sbin/wl
	rm usr/bin/wl
	rm sbin/wifi
	echo -e '#!/bin/sh\nexit 0' >usr/sbin/wl
	echo -e '#!/bin/sh\nexit 0' >usr/bin/wl
	echo -e '#!/bin/sh\nexit 0' >sbin/wifi
	rm ../2.4.30/wl.o				&& echo "broadcom-treiber weg"
	tar czf ../root.tgz *				&& echo "wl-zeux raus + neu einpacken"
	ls -l ../root.tgz
	cd ..
	ls -l
	echo "dies war '.' - loesche nun fff"
	rm -fR fff

	./gen-openwrt -v "${DESC}-madwifi-pppoe" -o "${FILE}.madwifi.pppoe.bin"	trx
	func_addinfo "${FILE}.madwifi.pppoe.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=MADWIFI_opt=PPPOE.bin"

	rm packages/freifunk-pppoecd-de*

	./gen-openwrt -v "${DESC}-madwifi" -o "${FILE}.madwifi.bin" trx
	func_addinfo "${FILE}.madwifi.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=MADWIFI.bin"

	mkdir fff
	cd fff
	tar xzf ../root_original.tgz
	rm usr/sbin/wl
	rm usr/bin/wl
	rm sbin/wifi
	echo -e '#!/bin/sh\nexit 0' >usr/sbin/wl
	echo -e '#!/bin/sh\nexit 0' >usr/bin/wl
	echo -e '#!/bin/sh\nexit 0' >sbin/wifi
	# rm ../2.4.30/wl.o
	tar czf ../root.tgz *
	ls -l ../root.tgz
	cd ..
	
	rm -fR packages

	./gen-openwrt -v "${DESC}-minimal" -o "${FILE}.minimal.bin" trx
	func_addinfo "${FILE}.minimal.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=NONE_opt=MINIMAL.bin"

	cd fff
	rm -fR www
	mkdir www
	touch www/cgi-bin-index.html
	rm usr/sbin/iptables
	rm usr/sbin/tc
	rm usr/sbin/olsrd-clearroutes
	rm usr/sbin/olsrd
	rm etc/init.d/*olsrd
	rm usr/lib/olsrd_*

	tar czf ../root.tgz *
	ls -l ../root.tgz
	cd ..

	./gen-openwrt -v "${DESC}-minimalistic" -o "${FILE}.minimalistic.bin" trx
	func_addinfo "${FILE}.minimalistic.bin" "linux=${KERNEL_VERSION}_format=TRX_wifidriver=NONE_opt=MINIMALISTIC.bin"

	func_addinfo show_explanation

	local BASE="root@intercity-vpn.de:/var/www/firmware/broadcom/images/testing/"

	echo "scp $FILE.* $BASE/linux=${KERNEL_VERSION}_format=..."
	while ! scp "${FILE}.bin"               "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=BROADCOM.bin" ;do sleep 3;done
	while ! scp "${FILE}.wlfull.bin"        "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=BROADCOMFULL.bin" ;do sleep 3;done
	while ! scp "${FILE}.wrt.bin"           "$BASE/linux=${KERNEL_VERSION}_format=WRT${filename_extension}_wifidriver=BROADCOM.bin" ;do sleep 3;done
	while ! scp "${FILE}.pppoe.bin"         "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=BROADCOM_opt=PPPOE.bin" ;do sleep 3;done
	while ! scp "${FILE}.pppoe.wlfull.bin"	"$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=BROADCOMFULL_opt=PPPOE.bin" ;do sleep 3;done
	while ! scp "${FILE}.madwifi.pppoe.bin" "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=MADWIFI_opt=PPPOE.bin" ;do sleep 3;done
	while ! scp "${FILE}.madwifi.bin"       "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=MADWIFI.bin" ;do sleep 3;done
	while ! scp "${FILE}.minimal.bin"       "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=NONE_opt=MINIMAL.bin" ;do sleep 3;done
	while ! scp "${FILE}.minimalistic.bin"  "$BASE/linux=${KERNEL_VERSION}_format=TRX${filename_extension}_wifidriver=NONE_opt=MINIMALISTIC.bin" ;do sleep 3;done
	while ! scp "/tmp/info.txt"             "$BASE/" ;do sleep 3;done

	while ! scp "/tmp/info.txt"		root@intercity-vpn.de:/var/www/firmware/ar71xx/images/testing/ ;do sleep 3;done

	rm "${FILE}.*"			|| echo "could not delete images"
	func_addinfo remove

	cd ..		# now we are in build
	cd ..	
	rm -fR firmware/*		|| echo "could not delete firmware-dir"
	rm -fR build/*			|| echo "could not delete build-dir"
}

func_addinfo ()
{
	local README="/tmp/info.txt"
	[ "$1" = "remove" ] && {
		[ -e "$README" ] && rm "$README"
		return
	}

	[ "$1" = "show_explanation" ] && {
		cat >>"$README" <<EOF

all the stuff is based on openWRT/whiterussian/freifunk-firmware ("$URL_FF")
and adds this repo: '$URL_FFF_TARBALL'

minimal.......: removed broadcom wifi-driver
minimalistic..: additionally removed /www-directory, iptables, tc and hole olsrd-stuff

EOF
		return
	}

	local FILE="$1"
	local DEST="$2" && [ -z "$DEST" ] && DEST="$FILE"
	local SIZE="$(stat -c %s "$FILE" )"
	local BLOCKS="$(( $SIZE / 65536 ))"

	[ $(( $SIZE % 65536 )) -gt 0 ] && BLOCKS=$(( $BLOCKS + 1 ))

	echo "block_oversize = '$(( $SIZE % 65536 ))'"
	
	[ ${#BLOCKS} -lt 2 ] && BLOCKS=" $BLOCKS"	# pad to right
	[ ${#SIZE}   -lt 7 ] && SIZE=" $SIZE"		# pad to right

	[ ! -e "$README" ] && {
		echo >>$README "GENERATED='$(date)'; VERSION='$UNIX'; VERSION_MAIN='$FF_VERSION'; KERNEL='2.4.30'; MAINTAINER='bittorf@bluebottle.com'"
		echo >>$README
	}

	BLOCKSTRING="               "
	[ "$DEST" != "tarball.tgz" ] && BLOCKSTRING="BLOCKS[64k]: $BLOCKS"

	echo "CRC[md5]: $( md5sum "$FILE" | cut -d' ' -f1 )  SIZE[byte]: $SIZE  ${BLOCKSTRING}  FILE: '$DEST'" >>"$README"

	echo "wrote info: $( tail -n1 $README )"
}

func_build_adblock ()
{
	local NETWORK="$1"
	local ADBLOCK_VERSION="$2"
	local WDIR="buildadblock"
	local ADBLOCKURL="http://pgl.yoyo.org/as/serverlist.php?showintro=0;hostformat=hosts"

	[ -z "$NETWORK" ] && {
		echo "func_build_adblock <network> <version>"
		return 1
	}

	mkdir $WDIR
	cd $WDIR

	echo >"debian-binary" "2.0"

	cat >control <<EOF
Package: fff-adblock-list
Priority: optional
Version: $ADBLOCK_VERSION
Architecture: all
Maintainer: Bastian Bittorf <bittorf@bluebottle.com>
Section: networking
Description: adblock-domain-list, fetched @ $(date)
Source: $ADBLOCKURL
EOF

	mkdir etc
	wget -O /dev/null "$ADBLOCKURL" || WGETERR="$WGETERR $ADBLOCKURL"
	wget -O -	  "$ADBLOCKURL" | sed -n 's/127.0.0.1 \(.*\)/\1/p' >"etc/hosts.drop"
	ls -l etc/hosts.drop

	tar --owner=root --group=root -cvzf data.tar.gz etc/hosts.drop

	tar --owner=root --group=root -cvzf control.tar.gz ./control

	tar --owner=root --group=root -cvzf ../fff-adblock-list_${ADBLOCK_VERSION}_mipsel.ipk ./debian-binary ./control.tar.gz ./data.tar.gz

	cd ..
	rm -fR "$WDIR"
	ls -l fff-adblock-list_${ADBLOCK_VERSION}_mipsel.ipk

	echo "scp fff-adblock-list_${ADBLOCK_VERSION}_mipsel.ipk root@intercity-vpn.de:/var/www/networks/$NETWORK/packages/"
	while ! scp fff-adblock-list_${ADBLOCK_VERSION}_mipsel.ipk root@intercity-vpn.de:/var/www/networks/$NETWORK/packages/ ;do sleep 3;done

	rm fff-adblock-list_${ADBLOCK_VERSION}_mipsel.ipk
}

func_build_missing_conntrack ()
{
        local URL="$URL_FF/openwrt-kmodules-freifunk-${FF_VERSION}.tar.bz2"
        local URL2="$URL_FF/openwrt-iptables-so-freifunk-${FF_VERSION}.tar.bz2"
        local IPKG_NAME="fff-missing-conntrack"
        local IPKG_VERSION="0.1.0"
        local IPKG_CPU="mipsel"
        local DATA_DIR="lib/modules/2.4.30"
        local DATA_DIR2="usr/lib/iptables"
        local WORKDIR="/tmp/$IPKG_NAME"

        rm -fR $WORKDIR
        mkdir  $WORKDIR
        cd     $WORKDIR

        echo "2.0" >"debian-binary"

        cat >control <<EOF
Package: $IPKG_NAME
Priority: optional
Version: $IPKG_VERSION
Architecture: $IPKG_CPU
Maintainer: Bastian Bittorf <bittorf@bluebottle.com>
Depends: iptables-mod-filter
Section: networking
Description: installs missing iptables-connection-tracking helpers (ftp,irc,h323...)
Source: $URL
EOF

        tar cvzf control.tar.gz ./control

	mkdir lib
        mkdir lib/modules
        mkdir lib/modules/2.4.30
        cd $DATA_DIR
        wget "$URL" || WGETERR="$WGETERR $URL"
        tar xjf openwrt-kmodules-freifunk-${FF_VERSION}.tar.bz2
        cd ..
        cd ..
        cd ..
        FILELIST=""
        FILELIST="$FILELIST $( find $DATA_DIR | grep -i ip_conntrack )"
        FILELIST="$FILELIST $( find $DATA_DIR | grep -i limit | grep -i ipt_ )"
	FILELIST="$FILELIST $( find $DATA_DIR | grep -i ip_nat_proto_gre.o )"

        mkdir usr
        mkdir usr/lib
        mkdir usr/lib/iptables
        cd $DATA_DIR2
        wget "$URL2" || WGETERR="$WGETERR $URL2"
        tar xjf openwrt-iptables-so-freifunk-${FF_VERSION}.tar.bz2
        cd ..
        cd ..
        cd ..
        FILELIST="$FILELIST $( find $DATA_DIR2 | grep -i ipt_.*limit )"
        FILELIST="$FILELIST $( find $DATA_DIR2 | grep -i libipt_REJECT.so )"

        tar cvzf data.tar.gz $FILELIST
        tar cvzf ${IPKG_NAME}_${IPKG_VERSION}_${IPKG_CPU}.ipk ./debian-binary ./control.tar.gz ./data.tar.gz

        rm -fR ${DATA_DIR}/
        rm data.tar.gz
        rm control
        rm control.tar.gz
        rm debian-binary

	echo "scp *.ipk root@intercity-vpn.de:/var/www/firmware/broadcom/packages/2.4.30/full/"
        while ! *.ipk root@intercity-vpn.de:/var/www/firmware/broadcom/packages/2.4.30/full/ ;do break ;done # fixme!

        rm -fR $WORKDIR
}

func_build_settings ()
{
	local NETWORK="$1"	# elephant | galerie | ...
	local VERSION="$2"	# 0.1 | 0.2 | ...

	local IPKG_NAME="mysettings"
	local IPKG_VERSION="${VERSION:-0.1}"
	local WDIR="build_settings_$NETWORK"
	local URL="http://www.datenkiste.org/cgi-bin/gitweb.cgi"
	local FILE="${IPKG_NAME}_${IPKG_VERSION}.ipk"

	mkdir $WDIR
	cd $WDIR

	local DIR="/home/$USER/Desktop/bittorf_wireless/kunden/galeriehotel,leipzigerhof/dokumentation"
	local CSV="345032-2009mai12-WLAN-Installation-Tabelle-Router_und_Standort.csv"

	cat >postinst <<EOF
#!/bin/sh

. /bin/needs vars_old base

[ "\$FFF_PLUS_VERSION" -lt 346172 ] && {
	ipkg remove horst libpcap libncurses freifunk-tcpdump
	wget -O /tmp/fw.tgz "http://intercity-vpn.de/firmware/broadcom/images/testing/tarball.tgz"
	cd /
	tar xzf /tmp/fw.tgz
	rm /tmp/fw.tgz
	/etc/init.d/S51crond_fff+ restart
}

. /tmp/NETPARAM
WIFIMAC="\$( ip -o link show dev \$WIFIDEV | sed -n 's/^.*ether \(..\):\(..\):\(..\):\(..\):\(..\):\(..\) .*/\1\2\3\4\5\6/p;q' )"
LANMAC="\$(  ip -o link show dev \$LANDEV  | sed -n 's/^.*ether \(..\):\(..\):\(..\):\(..\):\(..\):\(..\) .*/\1\2\3\4\5\6/p;q' )"

LINE="\$( grep ^"MAC=\"\$WIFIMAC\"" \$0 )"
[ -z "\$LINE" ] && LINE="\$( grep ^"MAC=\"\$LANMAC\"" \$0 )"
[ -n "\$LINE" ] && {
	echo
	echo "trying to apply '\$LINE'"
	eval \$LINE				# MAC|PROFILE|ESSID|HOST

	if [ "\$( nvram get wl0_ssid )" != "\$ESSID" -o "\$( nvram get fff_profile )" != "\$PROFILE" ]; then
		. /etc/functions_base_fff+ && func_need nvram log wifi
		. /etc/functions_profile_fff+
		. /etc/functions_profile_user_fff+
		. /etc/functions_profile_mac2profile_fff+

		MYLINE="\$LINE"
		func_nvset fff_profile  "\$PROFILE"
		func_profile_set_config "\$PROFILE"
		eval \$MYLINE

		func_nvset wan_hostname "\$HOST"
		func_nvset wl0_ssid "\$ESSID"
		func_nvset ff_nameservice
		func_nvset commit

		func_safe_reboot "new profile '\$PROFILE' enforced"
	else
		echo "already applied - ready"
	fi
}

exit

EOF
	sed -n 's/^[0-9]*,\("[0-9a-z]*"\),.*,.*,.*,.*,\(.*\),\(.*\),\(.*\),.*/MAC=\1;PROFILE=\2;ESSID=\3;HOST=\4;/p' "$DIR/$CSV" >>postinst

	cat postinst	# debug

	echo "2.0" >"debian-binary"

	cat >control <<EOF
Package: $IPKG_NAME
Version: $IPKG_VERSION
Priority: optional
Maintainer: Bastian Bittorf <technik@bittorf-wireless.de>
Section: net
Description: installs additional setting for '$NETWORK'
Source: $URL
EOF
	chmod 777 postinst

	tar --ignore-failed-read -czf ./data.tar.gz "" 2>/dev/null
	tar czf control.tar.gz ./control ./postinst
	tar czf "${IPKG_NAME}_${IPKG_VERSION}.ipk" ./debian-binary ./control.tar.gz ./data.tar.gz

	echo "scp "${IPKG_NAME}_${IPKG_VERSION}.ipk" root@intercity-vpn.de:/var/www/networks/$NETWORK/packages/"
	while ! scp "${IPKG_NAME}_${IPKG_VERSION}.ipk" root@intercity-vpn.de:/var/www/networks/$NETWORK/packages/ ;do sleep 3;done

	rm ./data.tar.gz ./debian-binary ./control.tar.gz control postinst
	cd ..
	rm -fR $WDIR
}

func_build_design ()
{
	local NETWORK="$1"		# elephant | galerie | ...
	local VERSION="${2:-0.1}"	# 0.1 | 0.2 | ...

	local IPKG_NAME="mydesign"
	local IPKG_VERSION="${VERSION:-0.1}"
	local WDIR="build_design_$NETWORK"
	local URL="http://www.datenkiste.org/cgi-bin/gitweb.cgi"
	local FILE="${IPKG_NAME}_${IPKG_VERSION}.ipk"
	local MYFILE
	local BW="$HOME/Desktop/bittorf_wireless"
	local BASE
	local BUILD_DATE="$( date "+%d-%b-%Y" )"

	mkdir -p "$WDIR"
	cd "$WDIR"
	mkdir -p "www/images"
	mkdir -p "www/cgi-bin"

	cp $HOME/Desktop/bittorf_wireless/kunden/Hotel_Elephant/grafiken/weblogin/button_login_de.gif  www/images/

	_copy_favicon_bittorf ()
	{
		local FAVDEST="www/favicon.ico"

		cp $HOME/Desktop/bittorf_wireless/vorlagen/grafiken/weblogin/favicon.ico $FAVDEST || echo "error favicon?!"
	}

	_copy_favicon_freifunk ()
	{
		wget -O www/favicon.ico "http://weimarnetz.de/favicon.ico" || echo "download favicon-fehler!"
	}

	_copy_flags ()		# fixme! jp=ja,dk=da
	{
		local DIR="$BW/vorlagen/grafiken/weblogin/flaggen"

		cp $DIR/flag_de.gif 				www/images/
		cp $DIR/flag_en.gif 				www/images/
		cp $DIR/flag_fr.gif				www/images/
		cp $DIR/flag_ru.gif				www/images/
		cp $DIR/flag_dk.gif				www/images/flag_da.gif
		cp $DIR/flag_jp_16x12_2colors_websafe.gif	www/images/flag_ja.gif
	}

	_copy_ticket_usernames ()		# not used anymore
	{
		local THEME="$1"
		local PROFILE="$2"
		local LANG="${3:-de}"

		local DATA LINE LINES I DESCRIPTION
		
		local DESTINATION="etc/kalua/random_username"
		mkdir -p etc/kalua

		case "$THEME" in
			animals_de|capital_citys_de|artists_leipzig_de|componists_de)
				DATA="$BW/vorlagen/grafiken/weblogin/passwords/$THEME.txt"

				case "$THEME" in
					capital_citys_de)
						DESCRIPTION="Hauptst&auml;dte der Welt"
					;;
					artists_leipzig_de)
						DESCRIPTION="K&uuml;nstler der Leipziger Schule"
					;;
					componists_de)
						DESCRIPTION="K&uuml;nstler der klassischen Musik"
					;;
					*)
						DESCRIPTION="unspezifiziert"
					;;
				esac
			;;
		esac

		LINES="$( cat "$DATA" | wc -l )"
		LINES=$(( $LINES + 0 ))

		echo  >$DESTINATION	"_random_username_do ()		# theme: '$THEME'"
		echo >>$DESTINATION	"{"
		echo >>$DESTINATION	"	local o"
		echo >>$DESTINATION	"			case \"\$( _math random_integer 1 $LINES )\" in"

		while read LINE; do {
			I=$(( ${I:-0} +1 ))
			echo >>$DESTINATION "				$I) o=\"$LINE\";;"
		} done <"$DATA"

		echo >>$DESTINATION	"				*) o=\"$LINE\";;"		# to be safe
		echo >>$DESTINATION	"			esac"
		echo >>$DESTINATION	"}"
		echo >>$DESTINATION     ""
		echo >>$DESTINATION	"_random_username_namespace ()"
		echo >>$DESTINATION     "{"
		echo >>$DESTINATION     "	echo '$DESCRIPTION ($LINES)'"
		echo >>$DESTINATION     "}"

		echo "Usernames:"
		ls -l "$DESTINATION"
		echo
		cat "$DESTINATION"
		echo "# please hit ENTER to continue, or CTRL+C to abort"
		read DATA
	}

	_lowercase ()
	{
		echo -n "$1" | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
	}

	_uppercase ()
	{
		echo -n "$1" | sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'
	}


	_login_gen ()
	{
		local USERNAME="$1"
		local PASSWORD="$2"

		local USERNAME_B1="$(   echo $USERNAME | cut -b1 )"
		local PASSWORD_B1="$(   echo $PASSWORD | cut -b1 )"
		local USERNAME_REST="$( echo $USERNAME | cut -b2-99 )"
		local PASSWORD_REST="$( echo $PASSWORD | cut -b2-99 )"

		Ul="$( _lowercase "$USERNAME_B1" )$USERNAME_REST"
		Uu="$( _uppercase "$USERNAME_B1" )$USERNAME_REST"
		Pl="$( _lowercase "$PASSWORD_B1" )$PASSWORD_REST"
		Pu="$( _uppercase "$PASSWORD_B1" )$PASSWORD_REST"

		echo "$( echo -n "$Ul$Pl" | md5sum | cut -d' ' -f1) 1 nolimit $Ul $Pl"
		echo "$( echo -n "$Ul$Pu" | md5sum | cut -d' ' -f1) 2 nolimit $Ul $Pu"
		echo "$( echo -n "$Uu$Pl" | md5sum | cut -d' ' -f1) 3 nolimit $Uu $Pl"
		echo "$( echo -n "$Uu$Pu" | md5sum | cut -d' ' -f1) 4 nolimit $Uu $Pu"
	}

	_copy_terms_of_use ()
	{
		local USERDIR="$1"
		local DATE="$( date "+%Y %b %d" | sed -e 's/ä/a/g' )"	# Maerz
		local SHORT_LANG FILE

		cp "$USERDIR/rules_meta_de.txt"	"www/images/weblogin_rules_de_meta"
		cp "$USERDIR/rules_meta_en.txt"	"www/images/weblogin_rules_en_meta"
		cp "$USERDIR/rules_meta_fr.txt"	"www/images/weblogin_rules_fr_meta"

		for LANG in de en fr; do {
			FILE="www/images/weblogin_rules_${LANG}_meta"
			grep -q ^"ERSTELLUNGSZEIT=" "$FILE" && {
				sed -i '/^ERSTELLUNGSZEIT=/d' "$FILE"
			}

			echo "ERSTELLUNGSZEIT='$DATE'" >>"$FILE"
		} done

		for LANG in deutsch-ISO_8859-1 english-ISO_8859-1 france-ISO_8859-15; do {
			SHORT_LANG="$( echo $LANG | cut -b1-2 )"
			FILE="$BW/vorlagen/nutzungsbedingungen/nutzungsbedingungen_$LANG.txt"
			DEST="www/images/weblogin_rules_${SHORT_LANG}.txt"

			sed "s/\${ERSTELLUNGSZEIT}/$DATE/g" "$FILE" >"$DEST"
		} done
	}

	die()
	{
		echo "fatal error"
		exit 1
	}

	case $NETWORK in
		example)
			continue
			# idea:
			# uses flags=standard favicon=standard usageterms=standard ...

			_copy_favicon_bittorf
			# /www/favicon.ico				# _copy_favicon
			
			_copy_flags
			# /www/images/weblogin/flag_[de|en|fr].gif	# _copy_flags	// Sprach-Symbole (deutsch koennte die Flagge ch|at|de sein?)
			# userdb_login_template.pdf

			# /www/images/button_login_de.gif		# Absendeknopf, farblich abgestimmt
			# /www/images/logo2.gif 			# Slogan-Grafik "Galerie Hotel Leipziger Hof \n Hier schlafen (surfen) sie mit einem Original"
			# /www/images/logo.gif				# Hauptlogo
			# /www/images/landing_page.txt			# http://url
			# /www/images/bgcolor.txt			# HTML z.b. '#FFD700' oder 'yellow'

			_login_gen "username" "password" >www/cgi-bin/userdata.txt
			# /www/cgi-bin/userdata.txt			# default-passwoerter, format: "md5sum(${user}${pass}) kommentar"

			_copy_terms_of_use "$BASE"
			# /www/images/weblogin_rules_[de|en|fr_meta	# _copy_terms_of_use
			# /www/images/weblogin_rules_[de|en|fr].txt	# _copy_terms_of_use
		;;
		elephant)
			BASE="$BW/kunden/Hotel_Elephant/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/landing_page.txt"	  	www/images/
			cp "$BASE/logo.gif"			www/images/
			cp "$BASE/button_login_de.gif" 		www/images/button_login_de.gif
		;;
		galerie)
			BASE="$BW/kunden/galeriehotel,leipzigerhof/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"	www/images/button_login_de.gif
			cp "$BASE/landing_page.txt" 	www/images/
			cp "$BASE/logo.gif"		www/images/
			cp "$BASE/logo2.gif"		www/images/
			cp "$BASE/bgcolor.txt"		www/images/
		;;
		zumnorde)
			BASE="$BW/kunden/Hotel_Zumnorde/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/landing_page.txt" 			www/images/
			#cp "$BASE/logo.gif"				www/images/
			cp "$BASE/logo-zumnorde_aus_eps_320px.gif"	www/images/logo.gif
		;;
		versilia|versiliawe|versiliaje)							# fixme! loginbutton?
			BASE="$BW/kunden/versilia/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"
#			_login_gen "versilia" "spaghetti"	>www/cgi-bin/userdata.txt

			cp $BASE/logo.gif				www/images/
			cp $BASE/landing_page.txt			www/images/landing_page.txt
		;;
		ejbw)
			BASE="$BW/kunden/EJBW/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif		www/images/
			cp $BASE/logo.gif			www/images/logo.gif
			cp $BASE/bgcolor.txt			www/images/bgcolor.txt
		;;
		rehungen)
			BASE="$BW/kunden/Breitband-Rehungen/grafiken/weblogin/"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif				www/images/
			cp $BASE/rehungen_logo_transparent_32cols_220px.gif	www/images/logo.gif
			cp $BASE/bgcolor.txt					www/images/bgcolor.txt
		;;
		aschbach)
			BASE="$BW/kunden/cans-niko_jovicevic/Berghotel_Aschbach_WLAN-System/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton.gif					www/images/button_login_de.gif
			cp $BASE/logo-Aschbach_transparent_cropped_400px_16cols.gif	www/images/logo.gif
			cp $BASE/bgcolor.txt						www/images/bgcolor.txt
		;;
		abtpark)
			BASE="$BW/kunden/Abtnaundorfer_Park/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		dummy)
			BASE="$BW/vorlagen/weblogin_design/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		schoeneck)
			BASE="$BW/kunden/IFA Schöneck/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		dhsylt)
			BASE="$BW/kunden/dorfhotel_sylt/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/generic-dorfhotel.gif"		www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		xoai)
			BASE="$BW/kunden/hotel_xoai_vietnam/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login.gif"			www/images/button_login_de.gif
			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		ibfleesensee)
			BASE="$BW/kunden/tui-iberotel_fleesensee/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		dhfleesensee)
			BASE="$BW/kunden/Dorfhotel Fleesensee/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
			cp "$BASE/logo_dorfhotel_fleesensee.gif"	www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
			cp "$BASE/font_face.txt"			www/images/font_face.txt
			cp "$BASE/font_color.txt"			www/images/font_color.txt
		;;
		fparkssee)
			BASE="$BW/kunden/ferienpark_scharmuetzelsee/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/loginbutton.gif"			www/images/button_login_de.gif
			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/bgcolor.txt"				www/images/bgcolor.txt
		;;
		olympia)
			BASE="$BW/kunden/cans-niko_jovicevic/Hotel-Olympia_Muenchen/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"		www/images/button_login_de.gif
			cp "$BASE/olympia-crop.gif"		www/images/logo2.gif
			cp "$BASE/balken.gif"			www/images/logo.gif
			cp "$BASE/bgcolor.txt"			www/images/bgcolor.txt
			cp "$BASE/font_face.txt"		www/images/font_face.txt
			cp "$BASE/font_color.txt"		www/images/font_color.txt
		;;
		spbansin)
			BASE="$BW/Akquise/Angebote_Ferienparks/Bansin/Seepark Bansin/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/button_login_de.gif"						www/images/button_login_de.gif
			cp "$BASE/logo_seepark_bansin_crop_190px_alpha.gif"			www/images/logo.gif
			cp "$BASE/font_face.txt"						www/images/font_face.txt
			cp "$BASE/font_color.txt"						www/images/font_color.txt
		;;
		itzehoe)
			BASE="$BW/kunden/stadtwerke_itzehoe/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton_orangerot.gif					www/images/button_login_de.gif
			cp $BASE/einzellogo_01_crop_16cols.gif					www/images/logo.gif
			cp $BASE/font_face.txt							www/images/font_face.txt
			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		tkolleg)
			BASE="$BW/kunden/Thueringenkolleg/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton.gif						www/images/button_login_de.gif
			cp $BASE/tkolleg-merged-cropped.gif					www/images/logo.gif
			cp $BASE/bgcolor.txt							www/images/bgcolor.txt
			cp $BASE/font_face.txt							www/images/font_face.txt
			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		hotello-*)
			case "$NETWORK" in
				*K80)
					BASE="$BW/kunden/cans-niko_jovicevic/Hotello_K80-WLAN-System/grafiken/weblogin"
				;;
				*B01)
					BASE="$BW/kunden/cans-niko_jovicevic/Hotello_B01-WLAN-System/grafiken/weblogin"
				;;
				*F22)
					BASE="$BW/kunden/cans-niko_jovicevic/Hotello_F22-WLAN-System/grafiken/weblogin"
				;;
				*H09)
					BASE="$BW/kunden/cans-niko_jovicevic/Hotello_H09-WLAN-System/grafiken/weblogin"
				;;
				*)
					BASE="$BW/kunden/cans-niko_jovicevic/Hotello_H09-WLAN-System/grafiken/weblogin"
				;;
			esac

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de2_grau.gif					www/images/button_login_de.gif
			cp $BASE/Logo_Hotello_Gruppe_Blau_negativ_PANTONE_crop_251px.gif	www/images/logo.gif
			cp $BASE/bgcolor-dunkelblau.txt						www/images/bgcolor.txt
			cp $BASE/font_face.txt							www/images/font_face.txt
			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		limona)
			BASE="$BW/kunden/limona_weimar/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton.gif						www/images/button_login_de.gif
			cp $BASE/logo_16cols.gif						www/images/logo.gif
#			cp $BASE/font_face.txt							www/images/font_face.txt
#			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		shankar)
			BASE="$BW/kunden/shankar_peerthy/africa/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/adtag.js							www/advertisement.js
			cp $BASE/button_login_de.gif						www/images/button_login_de.gif
			cp $BASE/WiCloud_switzerlang_16cols.gif					www/images/logo.gif
			cp $BASE/font_face.txt							www/images/font_face.txt
			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		cupandcoffee)
			BASE="$BW/kunden/cup_und_coffee/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton.gif						www/images/button_login_de.gif
			cp $BASE/coffee_small.gif						www/images/logo.gif
			cp $BASE/font_face.txt							www/images/font_face.txt
			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		preskil)
			BASE="$BW/kunden/shankar_peerthy/mauritius/preskil/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton_orangerot.gif					www/images/button_login_de.gif
			cp $BASE/logo.gif							www/images/logo.gif
			cp $BASE/logo3.gif							www/images/logo3.gif
			cp $BASE/font_face.txt							www/images/font_face.txt
			cp $BASE/font_color.txt							www/images/font_color.txt
		;;
		satama)
			BASE="$BW/kunden/SATAMA/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/loginbutton.gif					www/images/button_login_de.gif
			cp $BASE/satama-logo_crop_217px.gif				www/images/logo.gif
			cp $BASE/bgcolor.txt						www/images/bgcolor.txt
		;;
		castelfalfi)
			BASE="$BW/kunden/castelfalfi/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif	www/images/
			cp $BASE/logo.gif		www/images/logo.gif
			cp "$BASE/bgcolor.txt"		www/images/bgcolor.txt
			cp "$BASE/font_face.txt"	www/images/font_face.txt
			cp "$BASE/font_color.txt"	www/images/font_color.txt
		;;
		marinabh)
			BASE="$BW/kunden/marina-boltenhagen/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif	www/images/
			cp $BASE/logo.gif		www/images/logo.gif
			cp "$BASE/bgcolor.txt"		www/images/bgcolor.txt
			cp "$BASE/font_face.txt"	www/images/font_face.txt
			cp "$BASE/font_color.txt"	www/images/font_color.txt
		;;
		boltenhagendh)
			BASE="$BW/kunden/tui-boltenhagen/dorfhotel/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif	www/images/
			cp $BASE/logo.gif		www/images/logo.gif
			cp "$BASE/bgcolor.txt"		www/images/bgcolor.txt
			cp "$BASE/font_face.txt"	www/images/font_face.txt
			cp "$BASE/font_color.txt"	www/images/font_color.txt
		;;
		giancarlo)
			BASE="$BW/kunden/Giancarlo/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif	www/images/
			cp $BASE/logo.gif		www/images/logo.gif
			cp "$BASE/bgcolor.txt"		www/images/bgcolor.txt
			cp "$BASE/font_face.txt"	www/images/font_face.txt
			cp "$BASE/font_color.txt"	www/images/font_color.txt
		;;
		palais)
			BASE="$BW/kunden/palais_altstadt/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif	www/images/
			cp $BASE/logo.gif		www/images/logo.gif
			cp "$BASE/bgcolor.txt"		www/images/bgcolor.txt
			cp "$BASE/font_face.txt"	www/images/font_face.txt
			cp "$BASE/font_color.txt"	www/images/font_color.txt
		;;
		malchowit)
			BASE="$BW/kunden/malchowit/wlan-installationen/zimmer_mellentin/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif	www/images/
			cp $BASE/logo.gif		www/images/logo.gif
			cp "$BASE/bgcolor.txt"		www/images/bgcolor.txt
			cp "$BASE/font_face.txt"	www/images/font_face.txt
			cp "$BASE/font_color.txt"	www/images/font_color.txt
		;;
		leonardo)
			BASE="$BW/kunden/Leonardo_Leipzig/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp $BASE/button_login_de.gif			www/images/
			cp $BASE/logo_leonardo_Symbol_16cols.gif	www/images/logo.gif
		;;
		lisztwe)
			BASE="$BW/kunden/Messepark Leipzig Markkleeberg/Hotel_Liszt/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/logo.gif"		www/images/logo.gif
			cp "$BASE/loginbutton.gif"	www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"	www/images/
		;;
		adagio)
			BASE="$BW/kunden/Messepark Leipzig Markkleeberg/Hotel_Adagio/grafiken/weblogin"
		
			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/logo.gif"		www/images/logo.gif
			cp "$BASE/loginbutton.gif"	www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"	www/images
			cp "$BASE/bgcolor.txt"		www/images
		;;
		berlinle)
			BASE="$BW/kunden/hotel_berlin_in_leipzig/grafiken/weblogin"
		
			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/logo.gif"		www/images/logo.gif
			cp "$BASE/loginbutton.gif"	www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"	www/images
			cp "$BASE/bgcolor.txt"		www/images
		;;
		marinapark)
			BASE="$BW/kunden/dancenter_marinapark/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/DanCenter-Logo_GIF_transparent_crop_220px_8cols.GIF"	www/images/logo.gif
			cp "$BASE/loginbutton.gif"					www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"					www/images
			cp "$BASE/bgcolor.txt"						www/images
		;;
		vivaldi)
			BASE="$BW/kunden/vivaldi hotel/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/logo_alt.gif"					www/images/logo.gif
#			cp "$BASE/logo-vivaldi_hotel_leipzig_optimized.gif"	www/images/logo.gif
			cp "$BASE/loginbutton.gif"				www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"				www/images
			cp "$BASE/bgcolor.txt"					www/images
		;;
		apphalle)
			BASE="$BW/kunden/Messepark Leipzig Markkleeberg/AppartementhausHalle/grafiken/weblogin"
		
			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/logo.gif"		www/images/logo.gif
			cp "$BASE/loginbutton.gif"	www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"	www/images/
		;;
		sachsenhausen)
			BASE="$BW/kunden/elektro-schaefer/breitband_sachsenhausen/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf

			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/loginbutton.gif"			www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"			www/images/
			cp "$BASE/rules_meta_de.txt"			www/images/weblogin_rules_de_meta
			cp "$BASE/rules_meta_en.txt"			www/images/weblogin_rules_en_meta
			cp "$BASE/rules_meta_fr.txt"			www/images/weblogin_rules_fr_meta

			cp "$BW/vorlagen/nutzungsbedingungen/nutzungsbedingungen_deutsch-ISO_8859-1.txt"	www/images/weblogin_rules_de.txt
			cp "$BW/vorlagen/nutzungsbedingungen/nutzungsbedingungen_english-ISO_8859-1.txt"	www/images/weblogin_rules_en.txt
			cp "$BW/vorlagen/nutzungsbedingungen/nutzungsbedingungen_france-ISO_8859-15.txt"	www/images/weblogin_rules_fr.txt

			_login_gen "sachsenhausen" "weimar"	>www/cgi-bin/userdata.txt
		;;
		paltstadt)
			BASE="$BW/kunden/Elektro-Steinmetz/Pension_Altstadt/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"

			cp "$BASE/logo.gif"			www/images/logo.gif
			cp "$BASE/loginbutton.gif"		www/images/button_login_de.gif
			cp "$BASE/bgcolor.txt"			www/images/
		;;
		liszt28)
##			BASE="$BW/kunden/liszt28/weblogin"
#			BASE="$BW/kunden/liszt28/weblogin/lalaba"
#			BASE="$BW/kunden/liszt28/weblogin/barcamp2012"
			BASE="$BW/kunden/liszt28/weblogin/schlachthof"

			_copy_flags			|| die
			_copy_favicon_bittorf		|| die
			_copy_terms_of_use "$BASE"	|| die

#			wget -O www/images/logo.gif http://heartbeat.piratenfreifunk.de/images/logos_merged.png
#			cp "$BASE/foto-liszt28-vorderansicht.gif"	www/images/logo.gif
##			cp "$BASE/franz_liszt-partitur.gif"		www/images/logo.gif
##			cp "$BASE/button_login_de.gif"			www/images/button_login_de.gif
##			cp "$BASE/landing_page.txt"			www/images/
##			cp "$BASE/bgcolor.txt"				www/images/
#			echo "http://google.de/search?q=piraten+freifunk" >www/images/landing_page.txt

#			cp "$BASE/background_body_crop_400px.gif"	www/images/logo.gif
			cp "$BASE/image-schlacht001-schrift-440px-16cols.gif"	www/images/logo.gif	|| die
#			cp "$BASE/logo.gif"				www/images/logo.gif
			cp "$BASE/loginbutton.gif"			www/images/button_login_de.gif	|| die
			cp "$BASE/bgcolor.txt"				www/images/			|| die
#			cp "$BASE/landing_page.txt"			www/images/
#			cp "$BASE/font_face.txt"			www/images/
#			cp "$BASE/font_color.txt"			www/images/
		;;
		monami)
			BASE="$BW/kunden/monami/grafiken/weblogin"

			_copy_flags
			_copy_favicon_bittorf
			_copy_terms_of_use "$BASE"
			_login_gen "monami" "weimar"		>www/cgi-bin/userdata.txt

			cp "$BASE/monami-haus-64col.gif"	www/images/logo.gif
			cp "$BASE/button_login_de.gif"		www/images/button_login_de.gif
			cp "$BASE/landing_page.txt"		www/images/
		;;
		ffweimar)

			BASE="$BW/kunden/weimarnetz/grafiken/weblogin"

			_copy_flags											# really?
			_copy_favicon_freifunk

#			cp "$BASE/weimarnetz-mittelalter.jpg"			www/images/intro.jpg
			cp "$BASE/schaeuble/head.gif"				www/
			cp "$BASE/schaeuble/watching.js"			www/
#			cp "$BASE/logocontest-itten-brahm17-transparent.gif"	www/images/logo.gif			# really?
			cp "$BASE/ulis_logo.gif"				www/images/logo.gif
			cp "$BASE/button_login_de.gif"				www/images/button_login_de.gif		# really?


			# http://wireless.subsignal.org/index.php?title=Bild:Falke16.jpg
			# http://wireless.subsignal.org/images/d/d4/Die_suche_klein.JPG
			# http://wireless.subsignal.org/images/c/c7/Freifunkwiese_klein.jpg
			# http://wireless.subsignal.org/images/b/b6/Social_event.jpg
			# http://weimarnetz.de/freifunk/bilder/wirelessafrica.jpg
			# http://weimarnetz.de/freifunk/bilder/Node354_klein_schrift.jpg
		;;
	esac

	chmod -R 777 www	# rw-r-r

	ls -lR www/

	[ -e www/cgi-bin/userdata.txt ] && {
		echo
		echo "Userdata:"
		cat www/cgi-bin/userdata.txt
	}

	[ -e www/images/landing_page.txt ] && {
		echo
		echo "Landing Page: '$( cat www/images/landing_page.txt )'"
	}

	echo
	for MYFILE in $( find www/ -type f ); do {
		file -i "$MYFILE" | grep -q ": image/" && {
			echo "$( file -b "$MYFILE" )	$MYFILE"
		}
	} done
	echo

	[ -e 'www/images/button_login_de.gif' ] || {
		echo
		echo "ERROR - not found: www/images/button_login_de.gif"
		echo
	}

        echo "2.0" >"debian-binary"

        cat >control <<EOF
Package: $IPKG_NAME
Priority: optional
Version: $IPKG_VERSION
Maintainer: Bastian Bittorf <technik@bittorf-wireless.de>
Section: www
Description: installs all specific design elements for network '$NETWORK'
Architecture: all
Source: $URL
EOF

        tar --owner=root --group=root -cvzf control.tar.gz ./control
	tar --owner=root --group=root -cvzf data.tar.gz $( test -d www && echo www ) $( test -d etc && echo etc )
	tar --owner=root --group=root -cvzf $FILE ./debian-binary ./control.tar.gz ./data.tar.gz

	echo
	echo "scp $FILE root@intercity-vpn.de:/var/www/networks/$NETWORK/packages/"
	echo
	echo "# install with 'ipkg install http://intercity-vpn.de/networks/$NETWORK/packages/$FILE"
	echo "# press enter/return to continue, CTRL+C to abort"
	echo "# working directory: $( pwd )"

	read NOP
	while ! scp $FILE root@intercity-vpn.de:/var/www/networks/$NETWORK/packages/ ;do sleep 3;done
	
	cd ..
	rm -fR $WDIR
}

func_defs

case $1 in
	clean)
		for DIR in firmware build packages; do {

			[ -d $DIR ] && {
				echo "Inhalt von '$DIR':"
				ls -l $DIR

				echo "Verzeichnis '$DIR' loeschen? (j/n)"
				read WISH
		
				[ "$WISH" = "j" ] && rm -fR $DIR
			}
		} done

		for FILE in tarball.tgz root.tgz; do {
			[ -e "$FILE" ] && {
				echo "Datei $FILE loeschen?"
				ls -l "$FILE"

				read WISH

				[ "$WISH" = "j" ] && rm $FILE
			}
		} done
	;;
	start)
		logger -s "\$1: $1 \$2: $2"
		BUILD_OPTION="$2"			# name of enforced profile
		func_apply_own_files_to_ffkit "$BUILD_OPTION"
		func_build_missing_conntrack
	
		[ -n "$WGETERR" ] && {
			echo
			echo "wgeterr: $WGETERR"
			echo
		}

		echo "fertig!"
		echo "[START] $STARTTIME_DATE"
		echo "[READY] $(date)"
		echo "[OVERALL] $(( $( date +%s ) - $STARTTIME_UNIX ))sec"
		echo
	;;
	mirror_repo)
		URL="http://download.berlin.freifunk.net/ipkg/packages/"	# fixme! get from global_var
		LIST="$( wget -qO - "$URL" |
                          sed -n 's/^.*<a href=\"\([a-zA-Z0-9\._-]*\)[^a-zA-Z0-9\._-].*/\1/p' |
                           grep ^".*\.ipk$"
		)"

		for FILE in $LIST; do {
			wget "http://download.berlin.freifunk.net/ipkg/packages/$FILE"
		} done
	;;
	get_packages.sh)
		OUT="Packages"
		rm -f $OUT

		for FILE in $(ls -1 *.ipk); do {
			echo -en "$FILE: "

			tar xzf "$FILE" ./control.tar.gz
			tar xzf control.tar.gz ./control
	
			cat  >>$OUT control
			stat >>$OUT --printf "Size: %s\nFilename: %n\n\n" $FILE
			echo >>$OUT

			rm -f control control.tar.gz
	
			echo "ok"
		} done
	;;
	adblock)
		func_build_adblock $2 $3		# ffsundi
	;;
	design)
		[ -z "$2" ] && {
			echo "Usage: $0 design lisztwe (0.2|?)"
			exit 1
		}

		[ "$3" = "?" ] && {
			wget -qO - "http://intercity-vpn.de/networks/$2/packages/Packages" | while read LINE; do {

				case "$LINE" in
					*mydesign*) DIRTY=1 ;;
				esac

				case "$DIRTY" in
					1)
						case "$LINE" in
							Version*)
								echo $LINE
								exit 1
							;;
						esac
					;;
				esac

			} done

			exit 1
		}

		func_build_design $2 $3		# elephant 0.2
	;;
	settings)
		func_build_settings $2 $3	# galerie 0.1
	;;
	*)
		func_help
	;;
esac
