kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/dhfleesensee/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)


needing support?
join the [club](http://blog.maschinenraum.tk) or ask for [consulting](http://bittorf-wireless.de)

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=weimarnetz&url=https://github.com/weimarnetz/weimarnetz&title=weimarnetz&language=&tags=github&category=software)


how to get a release for a specific hardware
--------------------------------------------

	# login as non-root user
	git clone git://github.com/weimarnetz/weimarnetz.git
	mkdir myrelease; cd myrelease
	DO="../weimarnetz/openwrt-build/build_release.sh"

	# choose your router-model and build, for example:
	$DO "HARDWARE.Linksys WRT54G:GS:GL" ffweimar_standard b43minimal kernel.addzram patch:901-minstrel-try-all-rates.patch patch:luci-remove-freifunk-firewall.patch ffweimar_luci_standard
	$DO "HARDWARE.TP-LINK WR841ND" ffweimar_standard kernel.addzram patch:901-minstrel-try-all-rates.patch patch:luci-remove-freifunk-firewall.patch ffweimar_luci_standard hostapd
	#build all ar71xx based hardware images 
	$DO "HARDWARE.ar71xx" ffweimar_standard kernel.addzram patch:901-minstrel-try-all-rates.patch patch:luci-remove-freifunk-firewall.patch ffweimar_luci_standard hostapd vtunnoZlibnoSSL
	$DO "HARDWARE.Buffalo WZR-HP-AG300H" standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention trafficshaping kcmdlinetweak
	$DO "HARDWARE.TP-LINK TL-WR1043ND" standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention trafficshaping kcmdlinetweak
	$DO "HARDWARE.TP-LINK WR841ND" standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention trafficshaping kcmdlinetweak
	$DO "HARDWARE.Linksys WRT54G:GS:GL" standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention nopppoe b43minimal olsrsimple nohttps nonetperf kcmdlinetweak
	$DO "HARDWARE.Ekuku-Longshot" standard kernel.addzram patch:901-minstrel-try-all-rates.patch dataretention nopppoe b43minimal olsrsimple nohttps nonetperf unoptimized kcmdlinetweak
	# explanation follows soon


how to build this from scratch on a debian server
-------------------------------------------------

	# be root user
	apt-get update
	LIST="build-essential libncurses5-dev m4 flex git git-core zlib1g-dev unzip subversion gawk python libssl-dev quilt screen"
	for PACKAGE in $LIST; do apt-get -y install $PACKAGE; done

	# now login as non-root user, use 'git clone --depth 1 ...' if history doesnt matter (faster download)
	git clone git://nbd.name/openwrt.git
	git clone git://nbd.name/packages.git
	cd openwrt
	git clone git://github.com/weimarnetz/weimarnetz.git

	# for working with a specific openwrt-revision, do this:
	# REV=33867	// current testing
	# REV=33726	// current beta
	# REV=33726	// current stable
	# git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$REV " | cut -d' ' -f2 )" -b r$REV

	# now copy your own 'apply_profile.code.definitions' to . or the provided one will be used

	make menuconfig				# select your "Target System" / "Target Profile" and exit
	make package/symlinks

	# now configure your image, see next
	# section "configure the builtin-packages"

	# last 3 arguments enforce a specific configuration (profile: ffweimar, wifmode: adhoc, node: 42)
	weimarnetz/openwrt-build/mybuild.sh applymystuff "ffweimar" "adhoc" "42"	# omit arguments for a generic image
	weimarnetz/openwrt-build/mybuild.sh make 					# needs some hours + 5gig of space

	# flash your image via TFTP
	FW="/path/to/your/baked/firmware_file"
	IP="your.own.router.ip"
	while :; do atftp --trace --option "timeout 1" --option "mode octet" --put --local-file $FW $IP && break; sleep 1; done


configure the builtin-packages
------------------------------

	# the fast and easy automatic way:
	weimarnetz/openwrt-build/mybuild.sh set_build standard
	make defconfig

	# the way to understand what you are doing here:
	make kernel_menuconfig		# will safe in 'build_dir/linux-${platform}/linux-${kernelversion}/.config'

		General setup ---> [*] Support for paging of anonymous memory (swap)
		Device Drivers ---> Staging drivers ---> [*] Compressed RAM block device support

	make menuconfig 		# will safe in '.config'

		Global build settings ---> [*] Compile the kernel with symbol table information

		Base system ---> busybox ---> Linux System Utilities ---> [*] mkswap
									  [*] swaponoff
		Base system ---> [ ] firewall

		Network ---> Firewall ---> [*] iptables ---> [*] iptables-mod-ipopt
							     [*] iptables-mod-nat-extra

		Network ---> Routing and Redirection ---> [*] ip
		Network ---> Routing and Redirection ---> [*] olsrd ---> [*] olsrd-mod-arprefresh
									 [*] olsrd-mod-jsoninfo
									 [*] olsrd-mod-nameservice
									 [*] olsrd-mod-txtinfo
									 [*] olsrd-mod-watchdog
		Network ---> Web Servers/Proxies ---> [*] uhttpd
						      [*] uhttpd-mod-tls
						      [*] Build with debug messages

		Network ---> [*] ethtool	# if needed, e.g. 'Dell Truemobile 2300'
		Network ---> [*] mii-tool	# if needed, e.g. 'Ubiquiti Bullet M5'
		Network ---> [*] netperf
		Network ---> [*] ulogd ---> [*] ulogd-mod-extra		# if data retention needed

		Utilities ---> [*] px5g
			       [*] rbcfg	# if needed, e.g. 'Linksys WRT54G/GS/GL'


how to development directly on a router
---------------------------------------

	opkg update
	opkg install git

	echo  >/tmp/gitssh.sh '#!/bin/sh'
	echo >>/tmp/gitssh.sh 'logger -s "$0: $*"'
	echo >>/tmp/gitssh.sh 'ssh -i /etc/dropbear/dropbear_dss_host_key $*'

	chmod +x /tmp/gitssh.sh
	export GIT_SSH="/tmp/gitssh.sh"		# dropbear needs this for public key authentication

	git config --global user.name >/dev/null || {
		git config --global user.name "Firstname Lastname"
		git config --global user.email "your_email@youremail.com"
		git config --edit --global
	}

	mkdir -p /tmp/dev; cd /tmp/dev
	git clone <this_repo>
	weimarnetz/openwrt-build/mybuild.sh build_ffweimar_update_tarball
	cd /; tar xvzf /tmp/tarball.tgz; rm /tmp/tarball.tgz

	cd /tmp/dev/weimarnetz
	git add <changed_files>
	git commit -m "decribe changes"
	git push ...


piggyback kalua on a new router model without building from scratch
-------------------------------------------------------------------

	# for new devices, which are flashed with a plain openwrt
	# from http://downloads.openwrt.org/snapshots/trunk/ do this:

	# plugin ethernet on WAN, to get IP via DHCP, wait
	# some seconds, connect via LAN with 'telnet 192.168.1.1' and

	# look with which IP was given on WAN, then do:
	ifconfig $(uci get network.wan.ifname) | fgrep "inet addr:"
	/etc/init.d/firewall stop
	/etc/init.d/firewall disable
	exit

	# plugin ethernet on WAN and connect to the router
	# via 'telnet <routers_wan_ip>', then do:
	opkg update
	opkg install ip bmon netperf
	opkg install olsrd olsrd-mod-arprefresh olsrd-mod-watchdog olsrd-mod-txtinfo olsrd-mod-nameservice
	opkg install uhttpd uhttpd-mod-tls px5g
	opkg install kmod-ipt-compat-xtables iptables-mod-conntrack iptables-mod-conntrack-extra iptables-mod-extra
	opkg install iptables-mod-filter iptables-mod-ipp2p iptables-mod-ipopt iptables-mod-nat iptables-mod-nat-extra
	opkg install iptables-mod-ulog ulogd ulogd-mod-extra

	# build full ffweimar-tarball on server
	weimarnetz/openwrt-build/mybuild.sh build_ffweimar_update_tarball full

	# copy from server to your router
	scp user@yourserver:/tmp/tarball.tgz /tmp/tarball.tgz
	# OR take this prebuilt one:
	wget -O /tmp/tarball.tgz http://46.252.25.48/tarball_full.tgz
	# decompress:
	cd /; tar xvzf /tmp/tarball.tgz; rm /tmp/tarball.tgz

	# execute config-writer
	/etc/init.d/apply_profile.code


Cherry Picking Git commits from forked repositories
---------------------------------------------------

* git fetch [repository url]
* git cherry-pick -x [hash]
* resolve conflicts, if any
    * git commit -ac [hash]
* git push

