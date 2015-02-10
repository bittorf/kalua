kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/dhfleesensee/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)

needing support?
join the [club](http://blog.maschinenraum.tk) or ask for [consulting](http://bittorf-wireless.de)

* [![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=bittorf&url=https://github.com/bittorf/kalua&title=kalua&language=&tags=github&category=software)
* donations in bitcoins are welcome and can be sent to 184Rzvif2EfpW1EycmL3SWt64n8L1vHQdJ


how to get a release for a specific hardware
--------------------------------------------

	# download and initial fetching of all sources
	# (start in an empty directory)
	wget https://raw.githubusercontent.com/bittorf/kalua/master/openwrt-build/build.sh
	sh build.sh --openwrt trunk

	mkdir openwrt_download    # all downloads are going into this dir
	cd openwrt

	# full build for specific target
	build.sh --openwrt r43102 --hardware 'all' --usecase 'Standard,kalua'

	# get detailed help with
	build.sh --help


how to build this from scratch on a debian server
-------------------------------------------------

	# work as root:
	apt-get update
	LIST="build-essential libncurses5-dev m4 flex git git-core zlib1g-dev unzip subversion gawk python libssl-dev quilt screen"
	for PACKAGE in $LIST; do apt-get -y install $PACKAGE; done

	# now login as non-root user
	git clone git://nbd.name/openwrt.git
	git clone git://nbd.name/packages.git
	cd openwrt
	git clone git://github.com/bittorf/kalua.git

	# for working with a specific openwrt-revision, do this:
	# REV=40860
	# git checkout $(git log -1 --format=%h --grep=@$REV)

	make menuconfig				# select your "Target System" / "Target Profile" and exit
	make package/symlinks

	# now configure your image and build:
	make menuconfig
	make

	# flash your image via TFTP
	FW="/path/to/your/baked/firmware_file"
	IP="your.own.router.ip"
	while :; do atftp --trace --option "timeout 1" --option "mode octet" --put --local-file $FW $IP && break; sleep 1; done

	# upload images to release-server:
	for CMD in applymystuff make "upload sysupgrade factory release remove"; do kalua/openwrt-build/mybuild.sh $CMD || break; done


manually configure the builtin-packages
---------------------------------------

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


Cherry Picking Git commits from forked repositories
---------------------------------------------------

	* git fetch <repository url>
	* git cherry-pick -x <hash>
	* resolve conflicts, if any
	** git commit -ac <hash>
	* git push


Special UCI-variables
---------------------

system.@weblogin[0].enabled		- bool
system.@weblogin[0].dhcpautologout	- bool
system.@weblogin[0].namespace		- string
system.@weblogin[0].logtraffic		- bool
system.@weblogin[0].defaultlang		- ISO 639-1
system.@weblogin[0].default_speed_up	- string: e.g. 16mbit
system.@weblogin[0].default_speed_down	- string: e.g. 384kbit
system.@weblogin[0].mac_unshaped	- string/list
system.@weblogin[0].authserver		- IP
system.@weblogin[0].gateway_check	- IP
system.@weblogin[0].dynamic_portfw	- pattern of macs
system.@weblogin[0].auth_credentials	- string
system.@weblogin[0].auth_type		- none, roomnumber, userpass
system.@weblogin[0].blocked		- bool
system.@weblogin[0].hideandseek		- bool
system.@weblogin[0].freelan		- bool
system.@weblogin[0].respect_missing_db	- bool
system.@weblogin[0].allow_wan		- bool

system.@monitoring[0].serverip		- IP
system.@monitoring[0].pingcheck		- IP
system.@monitoring[0].pingcheck_lazy	- bool
system.@monitoring[0].button_smstext	- text
system.@monitoring[0].button_phone	- list phonenumbers
system.@monitoring[0].url		- url
system.@monitoring[0].statusprecache    - bool
system.@monitoring[0].ignore_switch_error - bool
system.@monitoring[0].autoupload_config - bool
system.@monitoring[0].ignore_wifi_framecounter - bool
system.@monitoring[0].lazy_wifi_framecounter - bool
system.@monitoring[0].ignore_lossyethernet - bool

system.@admin[0].location		- string
system.@admin[0].latlon			- string
system.@admin[0].mail			- string
system.@admin[0].name			- string
system.@admin[0].phone			- string
system.@admin[0].neturl			- string

system.@vpn[0].hostname			- hostname
system.@vpn[0].ipaddr			- IP

system.@system[0].noswinstall		- bool
system.@system[0].avoid_autoreboot	- bool

system.@profile[0].name			- string
system.@profile[0].nodenumber		- integer
system.@profile[0].ipsystem		- string

system.@fwupdate[0].url			- url
system.@fwupdate[0].mode		- string: 0|stable|beta|testing

system.@vds[0].server			- scp-destination
system.@vds[0].enabled			- bool

system.@community[0].splash		- bool

system.@httpsproxy[0].enabled		- bool

olsrd.@meta[0].fixedarp			- bool
olsrd.@meta[0].throttle_traffic		- bool
olsrd.@meta[0].nexthop_dns		- bool
olsrd.@meta[0].reboot_weak_ethernet	- bool

firewall.@adblock[0].enabled		- bool
network.$INTERFACE.dyndns		- url

mail.@pop3[0].username			- string
mail.@pop3[0].password			- string
mail.@pop3[0].server			- hostname
mail.@pop3[0].port			- integer
mail.@smtp[0].server			- hostname
mail.@smtp[0].port			- integer
mail.@smtp[0].name			- string: e.g. realname
mail.@smtp[0].mail			- mailadresse
mail.@smtp[0].auth			- string: e.g. '-P 222 user@domain.tld:myfolder'

sms.@sms[0].admin			- string: phonenumber

wireless.radio0.cronactive		- string: '18:00 - 08:00'

network.wan.public_ip			- bool

system.@webcam[0].storage_path		- string: e.g. 'bastian@10.63.2.34:bigbrother'

olsrd.@meta[0].watch_value		- integer
olsrd.@meta[0].watch_ip			- ipaddr

network.@switch[0].disable_autoneg	- bool
