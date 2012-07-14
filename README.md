kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/dhfleesensee/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)

needing support?
join the [club](http://blog.maschinenraum.tk) or ask for [consulting](http://bittorf-wireless.de)

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=bittorf&url=https://github.com/bittorf/kalua&title=kalua&language=&tags=github&category=software)


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
	git clone git://github.com/bittorf/kalua.git

	# for working with a specific openwrt-revision, do this:
	# REV=32582; git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$REV " | cut -d' ' -f2 )" -b r$REV

	# now copy your own 'apply_profile.code.definitions' to . or the provided one will be used

	make menuconfig				# simply select exit, (just for init)
	make package/symlinks

	# now configure your image, see next
	# section "configure the builtin-packages"

	# last 3 arguments enforce a specific configuration (profile: ffweimar, wifmode: adhoc, node: 42)
	kalua/openwrt-build/mybuild.sh applymystuff "ffweimar" "adhoc" "42"	# omit arguments for a generic image
	kalua/openwrt-build/mybuild.sh make 					# needs some hours + 5gig of space

	# flash your image via TFTP
	FW="/path/to/your/baked/firmware_file"
	IP="your.own.router.ip"
	while :; do atftp --trace --option "timeout 1" --option "mode octet" --put --local-file $FW $IP && break; sleep 1; done


configure the builtin-packages
------------------------------

	make kernel_menuconfig
		General setup ---> [*] Support for paging of anonymous memory (swap)
		Device Drivers ---> Staging drivers ---> [*] Compressed RAM block device support

	make menuconfig 	# will safe in '.config'
		Base system ---> busybox ---> Linux System Utilities ---> [*] mkswap			# CONFIG_BUSYBOX_CONFIG_MKSWAP=y
									  [*] swaponoff			# CONFIG_BUSYBOX_CONFIG_SWAPONOFF=y

		Base system ---> [ ] firewall								# CONFIG_PACKAGE_firewall is not set

		Network ---> Firewall ---> [*] iptables ---> [*] iptables-mod-ipopt			# CONFIG_PACKAGE_kmod-ipt-ipopt=y
							     [*] iptables-mod-nat-extra			# CONFIG_PACKAGE_kmod-ipt-nat-extra=y

		Network ---> Routing and Redirection ---> [*] ip					# CONFIG_PACKAGE_ip=y
		Network ---> Routing and Redirection ---> [*] olsrd ---> [*] olsrd-mod-arprefresh	# CONFIG_PACKAGE_olsrd-mod-arprefresh=y
									 [*] olsrd-mod-jsoninfo		# CONFIG_PACKAGE_olsrd-mod-jsoninfo=y
									 [*] olsrd-mod-nameservice	# CONFIG_PACKAGE_olsrd-mod-nameservice=y
									 [*] olsrd-mod-txtinfo		# CONFIG_PACKAGE_olsrd-mod-txtinfo=y
									 [*] olsrd-mod-watchdog		# CONFIG_PACKAGE_olsrd-mod-watchdog=y

		Network ---> Web Servers/Proxies ---> [*] uhttpd					# CONFIG_PACKAGE_uhttpd=y
						      [*] uhttpd-mod-tls				# CONFIG_PACKAGE_uhttpd-mod-tls=y

		Network ---> [*] ethtool	# if needed, e.g. 'Dell Truemobile 2300'
		Network ---> [*] mii-tool	# if needed, e.g. 'Ubiquiti Bullet M5'
		Network ---> [*] netperf
		Network ---> [*] ulogd ---> [*] ulogd-mod-extra		# if data retention needed	# CONFIG_PACKAGE_kmod-ipt-ulog=y

		Utilities ---> [*] px5g									# CONFIG_PACKAGE_px5g=y
			       [*] rbcfg	# if needed, e.g. 'Linksys WRT54G/GS/GL'		# CONFIG_PACKAGE_robocfg=y


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
	kalua/openwrt-build/mybuild.sh build_kalua_update_tarball
	cd /; tar xvzf /tmp/tarball.tgz; rm /tmp/tarball.tgz

	cd /tmp/dev/kalua
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

	# build full kalua-tarball on server
	kalua/openwrt-build/mybuild.sh build_kalua_update_tarball full

	# copy from server to your router
	scp user@yourserver:/tmp/tarball.tgz /tmp/tarball.tgz
	# OR take this prebuilt one:
	wget -O /tmp/tarball.tgz http://46.252.25.48/tarball_full.tgz
	# decompress:
	cd /; tar xvzf /tmp/tarball.tgz; rm /tmp/tarball.tgz

	# execute config-writer
	/etc/init.d/apply_profile.code
