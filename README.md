kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/dhfleesensee/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)


Need support?
join the [club](http://www.weimarnetz.de) or ask for [consulting](http://bittorf-wireless.de)

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=weimarnetz&url=https://github.com/weimarnetz/weimarnetz&title=weimarnetz&language=&tags=github&category=software)

Important!
----------

> Don't forget to set the variables $REPONAME and $REPOURL as global variables (export VARIABLE=VALUE) before you start playing here. REPONAME is the directory where you checked out REPOURL.
> E.g. REPONAME could be set to weimarnetz and REPOURL to git://github.com/weimarnetz/weimarnetz.git

how to get a release for a specific hardware
--------------------------------------------
To build weimarnetz images on your own, you need some preparation steps and one line together with some options for hardware, features and packages. The commands are shown below.

All config options reside in openwrt-config/ and consist of fragments of openwrt config files or patch scripts you need to modify some files. You can add your own config file,hardware files must be named ```config_HARDWARE.NAME.txt```, features names are ```config_NAME.txt```.
Patch files must be saved in openwrt-patches/ and their name should descripe what they do.

You need to choose exactly one hardware and use it as the first argument prefixed with ```HARDWARE.``` (see example).

hardware bundles:

hardware | comment
-------- | -------
ar71xx | build all ar71xx based hardware (recommanded)
TP-LINK TLWR841ND | build TP-Link WR841N/ND images
Ubiquiti Bullet M | build Ubiquity images, mostly suitable for Bullets and Nanostations

Sometimes we need to patch some errors, because the won't be fixed that fast in openwrt or our requirements differ from the default approach. A patch in a commandline starts with ```patch:``` followed by the file name.

patches:

patch | comment
----- | -------
luci-remove-freifunk-firewall.patch | removes the firewall package from dependencies as we use our own tools
901-minstrel-try-all-rates-patch | changes minstrel behaviour to try all Wifi rates, without this patch wifi will fall back very often to 1MBit/s
openwrt-remove-ppp-firewall-from-deps.patch | removes pppoe and firewall from standard build, helps to reduce size
openwrt-remove-wpad-mini-from-deps.patch | removes wpad-mini from standard build, helps to reduce size

There some features you can add to your image and to the build process. They're simply added to the commandline by name.

feature packs:

feature | explanation
------- | -----------
ffweimar_standard | contains packages suitable and required for all weimarnetz installations
ffweimar_luci_standard | adds luci as standard web interface
hostapd | installs hostapd-mini to enable wireless AP (note: WPA isn't included)
https | enables https feature for uhhtpd
i18n_german | adds german translations
imagesbuilder | creates the imagebuilder file that is used for meshkit installations
options | creates a lot of modules that won't be included to the image by default. you can find these packages in bin/_arch_/packages
owm | installs openwifimap client to support http://map.weimarnetz.de
shrink | removes debug symbols to save space
tc | adds traffic control, i.e. to optimize olsr links
vtunnoZlibnoSSL | vpn client configured to connect to our vpn servers
use_trunk | build latest openwrt trunk instead of revisions written in openwrt-config/git_revs. add this option at the end of your line.
use_bb1407 | build from trunk ofbarrier breaker 14.07 final repo instead of revisions written in openwrt-config/git_revs from dev repos. add this option at the end of your line.

In the following box you'll find an example that builds our default image for weimarnetz routers based on ar71xx hardware. Simply call it step by step. Sometimes the build process will be interrupted. Mostly it's not an error, but some packages or dependencies of openwrt could not be downloaded. Try the last line again, if that happens. You could also debug that error by changing the directory to ```release/openwrt``` and call ```make V=s```.

	# login as non-root user
	export REPONAME="weimarnetz" && export REPOURL="git://github.com/weimarnetz/weimarnetz.git"
	git clone $REPOURL
	mkdir myrelease; cd myrelease
	DO="../$REPONAME/openwrt-build/build_release.sh"

	# choose your router-model and build, for example:
	#build all ar71xx based hardware images with barrier breaker 14.07 final
	$DO "HARDWARE.ar71xx" ffweimar_standard patch:901-minstrel-try-all-rates.patch patch:luci-remove-freifunk-firewall.patch patch:openwrt-remove-ppp-firewall-from-deps.patch patch:openwrt-remove-wpad-mini-from-deps.patch ffweimar_luci_standard hostapd vtunnoZlibnoSSL i18n_german https owm shrink tc use_bb1407


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
	export REPONAME="weimarnetz" && export REPOURL="git://github.com/weimarnetz/weimarnetz.git"
	git clone $REPOURL

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
	$REPONAME/openwrt-build/mybuild.sh applymystuff "ffweimar" "adhoc" "42"	# omit arguments for a generic image
	$REPONAME/openwrt-build/mybuild.sh make 					# needs some hours + 5gig of space

	# flash your image via TFTP
	FW="/path/to/your/baked/firmware_file"
	IP="your.own.router.ip"
	while :; do atftp --trace --option "timeout 1" --option "mode octet" --put --local-file $FW $IP && break; sleep 1; done


configure the builtin-packages
------------------------------

	# the fast and easy automatic way:
	$REPONAME/openwrt-build/mybuild.sh set_build standard
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
	git clone $REPOURL
	$REPONAME/openwrt-build/mybuild.sh build_kalua_update_tarball
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
	$REPONAME/openwrt-build/mybuild.sh build_kalua_update_tarball full

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
