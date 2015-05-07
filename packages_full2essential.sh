#!/bin/sh

# ToDo:
# fff-adblock-list
# fff-layer7-descriptions
# fff-missing-conntrack

[ -z "$1" ] && {
	echo "Usage: $0 start"
	echo "       must be called from essential dir!"
	exit 1
}

LIST="screen xrelayd kmod-ide busybox-tftp busybox-telnet freifunk-map-de freifunk-olsr-viz-de zlib"
LIST="$LIST kmod-usb dropbear kmod-ipt- iptables- kmod-sched fff- micro libpthread"
LIST="$LIST busybox-awk openssh-sftp-server busybox-nc busybox-coreutils sqlite3-cli libsqlite3 libreadline"
LIST="$LIST xyssl freifunk-secureadmin-de freifunk-pppoecd-de kmod-tun batmand-adv battool"
LIST="$LIST freifunk-dyndns-de libopenssl zlib liblzo vtun kmod-ext2 kmod-ext3 kmod-vfat rsync"
LIST="$LIST hdparm kmod-videodev libjpeg motion kmod-audio kmod-soundcore libid3tag"
LIST="$LIST libmad madplay rexima freifunk-radio wl-adv libgpg-error"
LIST="$LIST iwlib wireless-tools madwifi-tools kmod-madwifi libgcrypt vpnc"
LIST="$LIST kmod-rt73 kmod-spca5xx kmod-pwc9 kmod-pwc9x kmod-ov51x ov511 owshell"
LIST="$LIST kmod-usb-serial-pl2303 gpsd uclibc freifunk-usbstick kmod-firmware-class"
LIST="$LIST rrd librrd freifunk-statistics-de libpcap freifunk-tcpdump libncurses horst"
LIST="$LIST iptraf fftrace freifunk-recommended-de bwm ulogd freifunk-iptables-missing ow libusb"
LIST="$LIST kmod-mppe kmod-crypto kmod-gre kmod-ppp pptpd pppd ppp kmod-ipip"
LIST="$LIST libssl openvpn-ssl-lzo openvpn-nossl-nolzo freifunk-openwrt-compat busybox-crontab"
LIST="$LIST kmod-iptables-extra siproxd libosip2"
LIST="$LIST freifunk-netperf-de netperfbin robocfg"

for F in $LIST; do {
	cp 2>/dev/null ../full/${F}* . || echo "error during '$F'"
} done

