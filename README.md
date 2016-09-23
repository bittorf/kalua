kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/giancarlo/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)

needing support?
join the [club](http://blog.maschinenraum.tk) or ask for [consulting](http://bittorf-wireless.de)

[flattr]:	https://flattr.com/submit/auto?user_id=bittorf&url=https://github.com/bittorf/kalua&title=kalua&language=&tags=github&category=software
[flattrGFX]:	http://api.flattr.com/button/flattr-badge-large.png
[bitcoin]:	https://blockchain.info/address/184Rzvif2EfpW1EycmL3SWt64n8L1vHQdJ
[bitcoinGFX]:	http://intercity-vpn.de/files/bitcoin-button.png
[travis]:	https://travis-ci.org/bittorf/kalua
[travisGFX]:	https://travis-ci.org/bittorf/kalua.png

* [![flattr this repo][flattrGFX]][flattr]
* [![sending bitcoins][bitcoinGFX]][bitcoin]
* [![build status now][travisGFX]][travis]


TLDR!
-----

```
wget https://raw.githubusercontent.com/bittorf/kalua/master/openwrt-build/build.sh
sh build.sh --openwrt trunk && cd openwrt
../build.sh --openwrt r46693 --hardware 'La Fonera 2.0N' --usecase 'Standard,kalua'
```

how to get started
------------------

```
git clone https://github.com/bittorf/kalua.git
# or
# git clone git@github.com:bittorf/kalua.git

cd kalua
echo ".gitignore" >> .gitignore
echo "build-env" >> .gitignore

mkdir build-env
cd build-env

mkdir openwrt_download
ln -s -T ../openwrt-build/build.sh build.sh	# symlink our build tool
./build.sh --openwrt trunk			# fetch openwrt git repository
# valid version names are:  
# <empty>
# 'r12345'
# 'stable'
# 'beta'
# 'testing'
# 'trunk'
# 'switch_to_master'
#  'reset_autocommits'


# Example output:
# ~/tmp/kalua/build-env$ ./build.sh --openwrt trunk
# <14>Jun 10 00:45:06 ed: ./build.sh: check_working_directory() first start - fetching OpenWrt: git clone 'git://git.openwrt.org/openwrt.git'
# Cloning into 'openwrt'...
# remote: Counting objects: 312210, done.
# remote: Compressing objects: 100% (90882/90882), done.
# remote: Total 312210 (delta 214136), reused 303717 (delta 207431)
# Receiving objects: 100% (312210/312210), 110.89 MiB | 549.00 KiB/s, done.
# Resolving deltas: 100% (214136/214136), done.
# Checking connectivity... done.
# Checking out files: 100% (6204/6204), done.
# <14>Jun 10 00:49:00 ed: ./build.sh: check_working_directory() symlinking our central download pool
# <14>Jun 10 00:49:00 ed: ./build.sh: check_working_directory() first start - fetching OpenWrt-packages: git clone 'git://nbd.name/packages.git'
# Cloning into 'packages'...
# remote: Counting objects: 75921, done.
# remote: Compressing objects: 100% (28415/28415), done.
# remote: Total 75921 (delta 41370), reused 75038 (delta 40635)
# Receiving objects: 100% (75921/75921), 16.93 MiB | 405.00 KiB/s, done.
# Resolving deltas: 100% (41370/41370), done.
# Checking connectivity... done.
# <14>Jun 10 00:49:36 ed: ./build.sh: check_working_directory() first start - fetching own-repo: git clone 'git://github.com/bittorf/kalua.git'
# Cloning into 'kalua'...
# remote: Counting objects: 51055, done.
# remote: Compressing objects: 100% (175/175), done.
# remote: Total 51055 (delta 99), reused 0 (delta 0), pack-reused 50879
# Receiving objects: 100% (51055/51055), 14.71 MiB | 373.00 KiB/s, done.
# Resolving deltas: 100% (30245/30245), done.
# Checking connectivity... done.
# <14>Jun 10 00:50:08 ed: ./build.sh: check_working_directory() [OK] after doing 'cd openwrt' you should do:
# <14>Jun 10 00:50:08 ed: ./build.sh: check_working_directory() ../build.sh --help

# so after chaning to to openwrt directery, we can call our favorite config
cd openwrt
../build.sh --openwrt trunk --hardware 'TP-LINK TL-WDR3600' --usecase 'OpenWrt'

# so know package feeds will be updated, and installed
```


how to get a release for a specific hardware
--------------------------------------------

```
# download and initial fetching of all sources
# (start in an empty directory)
git clone https://github.com/bittorf/kalua.git

cd kalua
echo ".gitignore" >> .gitignore
echo "build-env" >> .gitignore

mkdir build-env
cd build-env

mkdir openwrt_download
../openwrt-build/build.sh --openwrt
../openwrt-build/build.sh --openwrt trunk

cd openwrt
# just build plain OpenWrt without any additions
../../openwrt-build/build.sh --openwrt trunk --hardware 'TP-LINK TL-WDR3600' --usecase 'OpenWrt'

# full build for specific target with kalua
build.sh --openwrt r45806 --hardware 'TP-LINK TL-WR1043ND' --usecase 'Standard,kalua'

# get detailed help with
build.sh --help
```


how to build this from scratch on a debian server
-------------------------------------------------

```
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
```


manually configure the builtin-packages
---------------------------------------

```
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
```


how to development directly on a router
---------------------------------------

```
opkg update
opkg install git

echo  >/tmp/gitssh.sh '#!/bin/sh'
echo >>/tmp/gitssh.sh 'logger -s -- "$0: $*"'
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
git commit -m "describe changes"
git push ...
```


piggyback kalua on a new router model without building from scratch
-------------------------------------------------------------------

```
# for new devices, which are flashed with a plain openwrt
# from http://downloads.openwrt.org/snapshots/trunk/ do this:

# plugin ethernet on WAN, to get IP via DHCP, wait
# some seconds, connect via LAN with 'telnet 192.168.1.1' and
# look with which IP was given on WAN, then do:
ip -family inet address show dev $(uci get network.wan.ifname)
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
```

Cherry Picking Git commits from forked repositories
---------------------------------------------------

```
# git fetch <repository url>
# git cherry-pick -x <hash>
# resolve conflicts, if any
# git commit -ac <hash>
# git push
```

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
	system.@weblogin[0].ticketstock		- integer
	system.@weblogin[0].db_cachesize	- integer
	system.@weblogin[0].db_localcopy	- bool
	system.@weblogin[0].db_forcefuzzy	- bool
	system.@weblogin[0].force_lan_reachable - bool
	system.@weblogin[0].always_reachable	- bool
	system.@weblogin[0].redirect_dns	- bool
	system.@weblogin[0].allow_cgi_roles	- bool
	
	system.@monitoring[0].serverip		- IP
	system.@monitoring[0].backping		- nodenumber
	system.@monitoring[0].pingcheck		- IP
	system.@monitoring[0].pingcheck_lazy	- bool
	system.@monitoring[0].button_smstext	- text
	system.@monitoring[0].button_phone	- list phonenumbers
	system.@monitoring[0].url		- url
	system.@monitoring[0].statusprecache    - bool
	system.@monitoring[0].ignore_switch_error - bool
	system.@monitoring[0].report_switch_change - bool
	system.@monitoring[0].autoupload_config - bool
	system.@monitoring[0].ignore_wifi_framecounter - bool		# true = never restart wifi, even if no incoming wififrames for a long time
	system.@monitoring[0].lazy_wifi_framecounter - bool		# true = do not take missing incoming wififrames too serious (restart wifi after 10mins)
	system.@monitoring[0].ignore_lossyethernet - bool
	system.@monitoring[0].ignore_load	- bool
	system.@monitoring[0].cdp_send		- bool
	system.@monitoring[0].cisco_collect	- bool
	system.@monitoring[0].maxcost		- integer
	system.@monitoring[0].max_wificlients	- bool
	system.@monitoring[0].speedcheck_wired	- bool
	system.@monitoring[0].speedcheck_fakeip - IP
	system.@monitoring[0].roaming_stats	- bool
	system.@monitoring[0].report_traffic_nightly	- bool
	system.@monitoring[0].report_daily_stats - bool
	system.@monitoring[0].maintenance	- string, e.g. 'reverse_sshtunnel'
	system.@monitoring[0].maintenance_force - bool
	system.@monitoring[0].maintenance_ports - list of ints
	system.@monitoring[0].wifi_netparam_name - string, e.g. 'wlanadhocRADIO1'
	system.@monitoring[0].nightly_longrange - bool
	system.@monitoring[0].send_mapapi	- bool
	system.@monitoring[0].report_wantraffic - bool
	system.@monitoring[0].station_stats	- bool
	system.@monitoring[0].no_wiphy_restart	- bool
	system.@monitoring[0].toggle_wifi	- bool
	system.@monitoring[0].toggle_wifi_off	- clocktime
	system.@monitoring[0].toggle_wifi_on	- clocktime
	system.@monitoring[0].txpower_keep	- bool
	
	system.@admin[0].location		- string
	system.@admin[0].latlon			- string
	system.@admin[0].mail			- string
	system.@admin[0].name			- string
	system.@admin[0].phone			- string
	system.@admin[0].neturl			- string
	
	system.@vpn[0].hostname			- hostname
	system.@vpn[0].ipaddr			- IP
	system.@vpn[0].hideandseek_disabled	- bool
	system.@vpn[0].force			- bool
	system.@vpn[0].active			- bool
	system.vpn.dnsname			- string
	
	system.@system[0].noswinstall		- bool
	system.@system[0].avoid_autoreboot	- bool
	system.@system[0].db_backup_force	- bool
	system.@system[0].restrict_local	- bool (deny WANNET from MESH)
	system.@system[0].zram_size_mb		- integer
	system.@system[0].zram_disabled		- bool
	system.@system[0].leds_ignore		- bool
	
	system.@profile[0].name			- string
	system.@profile[0].nodenumber		- integer
	system.@profile[0].ipsystem		- string

	olsrd.@meta[0].hnaslave			- bool
	olsrd.@meta[0].hnaslave_dirty		- bool
	olsrd.@meta[0].hnaslave_condition	- e.g. '2 ap'
	olsrd.@meta[0].ignore_restarts		- bool
	olsrd.@meta[0].ignored_interfaces	- e.g. 'tap598 tap732'

	system.@fwupdate[0].url			- url
	system.@fwupdate[0].mode		- string: 0|stable|beta|testing
	system.@fwupdate[0].confirm_needed	- bool
	system.@fwupdate[0].confirm_timeout	- integer (days)

	system.@vds[0].server			- scp-destination
	system.@vds[0].enabled			- bool

	system.@community[0].splash		- bool

	system.@httpsproxy[0].enabled		- bool

	olsrd.@meta[0].fixedarp			- bool
	olsrd.@meta[0].throttle_traffic		- bool
	olsrd.@meta[0].nexthop_dns		- bool
	olsrd.@meta[0].reboot_weak_ethernet	- bool
	olsrd.@meta[0].watch_value		- integer
	olsrd.@meta[0].watch_ip			- ipaddr
	olsrd.@meta[0].allow_no_neigh		- bool

	firewall.@adblock[0].enabled		- bool
	firewall.@ignoreolsr[0].ip		- IP

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

	network.$INTERFACE.dyndns		- url
	network.$INTERFACE.shaping		- bool
	network.$INTERFACE.shaping_uplink	- integer [kbit]
	network.$INTERFACE.shaping_downlink	- integer [kbit]
	network.wan.public_ip			- bool
	network.@switch[0].disable_autoneg	- bool

	system.@webcam[0].storage_path		- string: e.g. 'bastian@10.63.2.34:bigbrother'
	system.@webcam[0].resolution		- string: e.g. '800x448'
	system.@webcam[0].flip_x		- bool
	system.@webcam[0].flip_y		- bool
