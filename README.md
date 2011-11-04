kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/dhfleesensee/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)

needing support?
join the [club](http://blog.maschinenraum.tk) or ask for [consulting](http://bittorf-wireless.de)


how to build this from scratch on a debian server
-------------------------------------------------

	sudo apt-get update
	LIST="build-essential libncurses5-dev m4 flex git git-core zlib1g-dev unzip subversion gawk python libssl-dev"
	for PACKAGE in $LIST; do sudo apt-get install $PACKAGE; done
	
	git clone git://nbd.name/openwrt.git
	git clone git://nbd.name/packages.git
	cd openwrt
	
	make menuconfig				# simply select exit, (just for init)
	make package/symlinks
	make kernel_menuconfig		# simply select exit, (just for init)
	
	git clone git://github.com/bittorf/kalua.git
	kalua/openwrt-build/mybuild.sh gitpull
	kalua/openwrt-build/mybuild.sh show_known_hardware_models
	kalua/openwrt-build/mybuild.sh set_build_config "Linksys WRT54G:GS:GL"
	kalua/openwrt-build/mybuild.sh applymystuff "ffweimar" "adhoc" "42"
	
	[...needs some hours...]

	# flash your image via TFTP
	FW="/path/to/your/baked/firmware_file"
	IP="your.own.router.ip"
	while :; do atftp --trace --option "timeout 1" --option "mode octet" --put --local-file $FW $IP && break; sleep 1; done
